# Control-Plane Migration — hetzner → homelab (execution record)

**Status:** ✅ COMPLETED — 2026-09-23
**Branches:** `mig/join-homelab-phase1` (execution) → merged into `refactor/dry`
**Field guide:** `docs/control-plane-migration.md` (the how-to this record ran)
**Duration:** ~1 day, single maintenance window

## Final topology

```
internet ──► linode-us (45.33.39.244)
              │ nftables DNAT: 80/443 → 100.89.132.36:31557/32724 (UDP 443 → :31999)
              │ masquerade on tailscale0
              ▼
          homelab (100.89.132.36, tailnet)
              │ k3s v1.35.8+k3s1, single control-plane + etcd (quorum 1)
              │ traefik (helm) → Gateway API HTTPRoutes → apps
              │ flannel over tailscale0 · snapshot cron '0 */6 * * *'
              └── PVs: /mnt/fast (NVMe) + /mnt/hdd/k3s-storage (HDD)
hetzner-sg (5.223.55.249) — decommissioned: removed from repo, .sops.yaml,
             secrets, deploy-rs; cancel VPS (see follow-ups).
```

## What ran, phase by phase

### Phase 0 — prep

- Live-state dump → `pre-migration-state.yaml` (committed; reference only).
- `~/.kube/config.bak-hetzner` taken.
- **Deviation:** hetzner etcd snapshot **skipped** (user's call) — mitigated by
  forcing a homelab-side snapshot before decommission; **take one now if not
  done:** `ssh -t homelab 'sudo k3s etcd-snapshot save'`.

### Phase 1 — join (2-member etcd)

- Branch `mig/join-homelab-phase1`, homelab config → joining **server**
  (`role = "server"`, `serverAddr = https://10.0.0.1:6443`, shared `k3s-token`,
  wg-client overlay restored, etcd ports 2379/2380 on the wg mesh).
- Kept `--disable=traefik` / `--disable=local-storage` (match hetzner's flags;
  deviation from the guide's minimal sample — prevents chart re-install once
  homelab becomes leader).
- Verified: node gained `control-plane,etcd`, etcd 2/2 healthy, leases preserved
  (kubelet re-registered in place).

### Phase 2 — member removal + volume cleanup

- `etcdctl member remove 63044e73c12f33cd` (hetzner) while 2/2 healthy; quorum → 1.
- hetzner's k3s entered a restart loop (own-member removal) — harmless zombie.
- Stopped hetzner k3s, repointed kubeconfig to `https://100.89.132.36:6443`,
  deleted node `hetzner-sg`.
- **Decision (user):** alertmanager + cms-cp-mariadb workloads **deleted, not
  migrated** — both verified orphaned (alertmanager down 32d; mariadb sts 0/0
  for 232d; nothing referenced them; active DB is `cpkku-next-mariadb`).
  Data archives (if kept): `hetzner-pvs.tar.gz` on macair →
  `pvc-be248987-*` (alertmanager) + `pvc-bf9c6742-*` (cms-cp-mariadb).
- PVCs+PVs deleted (local-path reclaim; hetzner dirs orphaned by the stopped
  kubelet — irrelevant, box decommissioned).

### Phase 3 — end-state config

- `clusterInit = true` (harmless), wg removed, `--node-ip=100.89.132.36`,
  `--flannel-iface=tailscale0`, snapshot cron 6 h. Node IP flip + flannel
  re-subnet happened; services/NodePorts unaffected.

### Phase 4 — ingress cutover (linode)

- **Staged-config bug:** DNAT targeted `30080/30443` — those NodePorts never
  existed (traefik: `31557/32724/31999`). Fixed in `hosts/linode-us/default.nix`.
- homelab firewall opened the NodePorts **on `tailscale0` only**.
- **nftables quirk:** the nat table didn't load on deploy switch —
  `systemctl restart nftables` on linode (may recur on future deploys; consider
  `restartTriggers`).
- DNS: all A records `5.223.55.249 → 45.33.39.244` (incl. `*.napatsc.com`
  wildcard + `napatsc.net`).
- Certs: single wildcard via **DNS-01 (Cloudflare)** — no HTTP-01 dependency,
  renewal IP-independent (guide's "HTTP-01 through the proxy" did not apply).
- Verified externally: search/photos/audio **200**, git **303**, docs **302**.

### Phase 5 — clients (this record)

- kubeconfig = homelab's `k3s.yaml` repointed at the tailnet
  (`kubectl config set-cluster napatsc-cluster --server=https://100.89.132.36:6443`).
- SMB `code-stash` remounted by the launchd watchdog:
  `//samba@homelab:30445/code-stash` on macair ✓.
- Prometheus node-exporter: DaemonSet on the single node — auto-healthy.

### Phase 6 — hetzner decommission in-repo

- `git rm hosts/hetzner secrets/hetzner.yaml`; dropped `hetzner-sg` from
  `modules/nixos.nix` + `output.nix`; `.sops.yaml` key + creation rule removed;
  `sops updatekeys secrets/homelab.yaml` → recipients now admin+homelab only.
- `nix flake check` + homelab/linode eval clean; deploy nodes = homelab, linode-us.
- Commit `c8817a0`. VPS cancel still pending (user action below).

## Incident log (all resolved)

| Incident | Root cause | Fix |
| --- | --- | --- |
| ~half the pods `CreateContainerError` after phase-3 reboot | containerd upgrade `2.2.5-k3s2 → 2.2.7-k3s1` + kernel `6.18.48→6.18.52`: overlay snapshot metadata referenced missing layer dirs (`lowerdir ... err: no such file or directory`, 2.2k errors) | `systemctl restart k3s` (partial) → `crictl rmi --prune` hung (bbolt metadata corrupt) → **wiped `/var/lib/rancher/k3s/agent/containerd`**, full re-pull. No PV data touched. |
| `cpkku-next-mariadb` + `paperless-db` CrashLoop `ibdata1 lock error 11` | two orphaned `mariadbd` (pids) survived the containerd wipe holding InnoDB flocks | `sudo kill` orphans → fresh pods → InnoDB recovery clean. |
| degoog / cpkku-frontend `ImagePullBackOff` ("dial tcp 5.223.55.249:443") | private registry `images.napatsc.com` → old hetzner IP + MagicDNS 300 s TTL cache on homelab | DNS cutover + cache expiry; pods recovered. |
| linode public :80/:443 refused post-deploy | nftables nat table not loaded on switch | `systemctl restart nftables` (see quirk note). |
| qued: `local-large` storage class | provisioner has anti-control-plane affinity; post-migration the only node IS a control-plane | owner decision (follow-ups). |

## Follow-ups (open)

- [ ] `ssh -t homelab 'sudo k3s etcd-snapshot save && sudo k3s etcd-snapshot ls'` — confirm a snapshot exists before hetzner dies
- [ ] hetzner: `sudo systemctl stop k3s && sudo systemctl disable k3s` (zombie restart loop) — then **cancel the VPS** in the console
- [ ] (optional) rotate `smb-password` (+ k3s-token) — hetzner's age key can no longer decrypt `homelab.yaml`; rotation is defensive now
- [ ] `local-large` tier: relax affinity in homelab-helm **or** retire the HDD tier (6 Bound PVs safe either way; no new HDD volumes possible as-is)
- [ ] `cpkku-next-wordpress` CrashLoopBackOff + nextcloud root 500 — pre-existing app issues, not migration fallout
- [ ] linode: add `systemd.services.nftables.restartTriggers` so the DNAT survives future deploys
- [ ] clean untracked junk: `hetzner-etcd-snapshots/ keys/ nixos.qcow2 vzvm.json store-*.img result`

## How to destroy/rebuild this state

- Rollback to a single-member hetzner cluster is **not possible** (member
  removed, VPS pending decommission) — the restore path is homelab snapshots
  (`k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>`,
  snapshots via the 6 h cron).
- Redeploy homelab/linode: `nix run github:serokell/deploy-rs -- .#homelab`
  / `.#linode-us` (linode: restart nftables after, per quirk note).
