# Single-Cluster Control-Plane Migration: hetzner → homelab

> **STATUS: EXECUTED 2026-09-23** — this field guide was run to completion on
> `mig/join-homelab-phase1` (merged into `refactor/dry`). Execution record,
> incident log, deviations (snapshots skipped, workloads deleted not migrated)
> and standing follow-ups: `docs/control-plane-migration-summary.md`.

Field guide for moving the k3s control plane from `hetzner-sg` to `homelab`
**without rebuilding the cluster**: homelab joins the existing cluster as a
second server (embedded etcd grows to 2 members), then hetzner's etcd member
is removed and the VPS decommissioned. Workloads, PVCs, Ingresses, secrets and
certs are NEVER recreated — only the control-plane *location* changes.

Companion docs: `docs/install-nixos-on-linode.md` (linode provisioning),
`PLAN.md` (repo history). The end-state repo config (homelab = standalone
server, linode = nftables ingress proxy) is already staged; what this document
adds is the **temporary** phase-1/2 configuration and the operational
choreography to get there safely.

## Why this approach

- **No PVC renames.** local-path names volumes `pvc-<uid>_<ns>_<pvcname>`;
  because the cluster identity (etcd state) is preserved, every PV object — and
  every one of the ~40 data directories on homelab's disks — keeps its name and
  stays bound. No `mv`, no redeploys from homelab-helm, no NodePort re-pinning.
- **Hetzner is the safety net, not a backup target.** The old cluster keeps
  running until the new member is verified; rollback is trivial until the etcd
  member removal (step 6.3) — after that, hetzner holds nothing unique anyway.
- **Only ~3Gi crosses machines**: two local-path PVs that happen to be
  *node-scoped to hetzner* (see inventory). Everything else already lives on
  homelab's disks.

## Current-state inventory (verified 2026-09)

| | hetzner-sg | homelab |
| --- | --- | --- |
| k3s | `v1.35.8+k3s1` **server** (`clusterInit=true`, embedded etcd) | `v1.35.7+k3s2` **agent** |
| overlay | WireGuard `10.0.0.1/24` (wg-server) | WireGuard `10.0.0.2/24` (wg-client) |
| public | `5.223.55.249` (sshd :2222, **not on tailnet**) | behind NAT |
| tailnet | — | `100.89.132.36` (active) |
| data | `/mnt/fast/pvc-be248987…` (2Gi, `default/storage-prometheus-alertmanager-0`), `/mnt/fast/pvc-bf9c6742…` (1Gi, `cpkku/cms-cp-db-cms-cp-mariadb-0`) | 40 PVs across `/mnt/fast/*` (NVMe) + `/mnt/hdd/k3s-storage/*` (HDD); 159G + 11T free |
| ingress | traefik `LoadBalancer` → `5.223.55.249` (NodePorts 31557/32724, +31999/udp) | — |

Cluster token: `k3s-token` (encrypted in `secrets/homelab.yaml`, currently
materialized at `/home/napatsc/token.txt`). 2-member etcd quorum = **both
members up** — the single invariant that shapes the whole sequence.

## Phase 0 — prep (cluster untouched)

```sh
# 1. Etcd snapshot on hetzner (the true rollback point — BEFORE any change)
ssh -p 2222 napatsc@5.223.55.249 'sudo k3s etcd-snapshot save'
#    copy it off hetzner (it's about to die) — via wg is fastest:
ssh -p 2222 napatsc@5.223.55.249 \
  'sudo cp -r /var/lib/rancher/k3s/server/db/snapshots /tmp/snaps && sudo chown -R napatsc /tmp/snaps'
scp -P 2222 -r napatsc@5.223.55.249:/tmp/snaps ./hetzner-etcd-snapshots/

# 2. Save the live cluster state for reference
kubectl --context homelab get pv,pvc,sc -A -o yaml > pre-migration-state.yaml

# 3. Confirm homelab has room for the 3Gi + etcd db (~few hundred MB)
ssh homelab 'df -h /mnt/fast /mnt/hdd'

# 4. Backup macair kubeconfig
cp ~/.kube/config ~/.kube/config.bak-hetzner
```

Phase-1 config change is staged on git (step below); **do not deploy it yet**.

## Phase 1 — homelab joins as a second server

> The repo currently holds the **final** config. Create a temporary migration
> commit/branch with homelab as a *joining* server first:
> `git checkout -b mig/join-homelab-phase1`

`hosts/homelab/default.nix` — restore the agent-era bits, flip the role:

```nix
  sops.secrets.k3s-token.path = "/home/napatsc/token.txt";  # restore (needed to join)
  # sops.secrets.wireguard-client-private-key / -endpoint: restore both

  networking.wireguard.interfaces."wg-client" = { … };      # restore verbatim

  services.k3s = {
    enable = true;
    role = "server";                                  # ← the change
    tokenFile = config.sops.secrets.k3s-token.path;   # cluster token (shared)
    serverAddr = "https://10.0.0.1:6443";             # join the existing cluster
    # NO clusterInit — only the FIRST server sets that
    extraFlags = [
      "--node-ip=10.0.0.2"            # keep identity: node must not re-IP mid-migration
      "--flannel-iface=wg-client"     # keep pod network identical
      "--node-label=storage-tier=large"
      "--tls-san=homelab"             # prep for the post-hetzner kubeconfig
      "--tls-san=100.89.132.36"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 6443 9100 10250 2379 2380 ];  # 2379/2380 = etcd client/peer over wg
```

Rule of thumb: this config must look like the current *agent* config + the
two words `role = "server"` — plus etcd ports open. Nothing else changes.

```sh
git add -u && git commit -m "mig: homelab joins cluster as 2nd server (etcd)"
nix eval .#nixosConfigurations.homelab.config.system.build.toplevel.drvPath   # sanity
nix run github:serokell/deploy-rs -- .#homelab
```

**Verify the join** (from macair, via the *existing* kubeconfig):

```sh
kubectl --context homelab get nodes -o wide   # homelab now has control-plane role/etcd
kubectl --context homelab get pods -n kube-system -o wide | grep -E 'etcd|kube-apiserver'
sudo ssh homelab 'k3s etcd-snapshot ls'       # homelab now takes its own snapshots too
```

Keep the 2-member window short: both members up = quorum 2. Do phase 2 next.

## Phase 2 — remove hetzner from the cluster (order is the whole game)

**Trap: with exactly 2 members you cannot kill hetzner first.** 1/2 members up
= no quorum = API outage, and the removal proposal can't pass. The member must
be removed **while both are healthy**, THEN hetzner is stopped.

```sh
# 1. (optional-but-cheap) fresh snapshot on homelab, the remaining member
ssh homelab 'sudo k3s etcd-snapshot save'

# 2. List etcd members from homelab's own endpoint (cert path from the k3s data dir)
ssh homelab 'nix shell nixpkgs#etcd -c etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  member list'
#    → note the 64-bit hex ID of the hetzner member

# 3. Remove the hetzner member — BOTH members must be alive right now (quorum 2/2)
ssh homelab 'nix shell nixpkgs#etcd -c etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  member remove <hetzner-member-id>'
#    → result: 1 member remaining; cluster healthy (quorum is now 1)

# 4. Only now stop hetzner and drop its k8s node
ssh -p 2222 napatsc@5.223.55.249 'sudo systemctl stop k3s'
#    the API is now served only by homelab — repoint the existing kubeconfig
#    (same CA/client certs, cluster identity unchanged):
kubectl config set-cluster napatsc-cluster --server=https://100.89.132.36:6443
kubectl delete node hetzner-sg

# 5. Sanity: cluster is a single healthy member on homelab
kubectl get nodes; kubectl get events --all-namespaces | tail
```

The only unique data left on hetzner is its two node-scoped PVs
(`alertmanager`, `cms-cp-mariadb`) — copy it while the box is up:

```sh
# The two node-scoped PVs → staging on homelab (3Gi, over wg or public ssh)
ssh -p 2222 napatsc@5.223.55.249 'sudo tar -C /mnt/fast -cf - pvc-be248987-* pvc-bf9c6742-*' \
  | ssh homelab 'sudo mkdir -p /mnt/fast/_migration && sudo tar -C /mnt/fast/_migration -xf -'
```

**Rewrite those two volumes in the cluster** (StatefulSets → alertmanager,
cms-cp-mariadb now Pending on hetzner-scoped PVs): delete the PVCs, let them
recreate on homelab (local-path re-provisions there), then copy the staged data
into the new `pvc-<newuid>_…` dirs while the pods are scaled to 0 — same rename
pattern as any other volume, applied to just these two. `cp -a` (not `mv`)
since the staging copy may span saves; verify checksums.

## Phase 3 — finalize homelab networking (the staged config)

Switch the repo back to the end-state config (already in `main`): `role =
"server"`, `clusterInit = true` (harmless on an already-initialized etcd),
WireGuard removed, tailnet flannel:

```nix
services.k3s = {
  enable = true;
  role = "server";
  clusterInit = true;
  extraFlags = [
    "--disable=traefik"          # kept consistent with the helm-installed traefik
    "--disable=local-storage"
    "--node-external-ip=100.89.132.36"
    "--node-ip=100.89.132.36"             # ← add vs. the staged copy
    "--flannel-iface=tailscale0"          # ← add: tailnet-only pod network
    "--tls-san=homelab"
    "--tls-san=100.89.132.36"
    "--node-label=storage-tier=large"
    "--etcd-snapshot-schedule-cron='0 */6 * * *'"   # hardening, now that this is THE etcd
  ];
};
```

Node IP moves `10.0.0.2 → 100.89.132.36` once — expect pod re-IPs and one
flannel re-subnet; services/NodePorts (0.0.0.0-bind) are unaffected. Deploy,
then:
`kubectl get nodes -o wide`, `kubectl get pv,pvc -A | grep -v Bound` (must be
empty), spot-check a few apps' data.

## Phase 4 — ingress cutover (linode nftables proxy)

Deploy the already-staged linode config (DNAT `80/443 → 100.89.132.36:30080/
30443`, UDP 31999 for QUIC, masquerade on `tailscale0`):

```sh
nix run github:serokell/deploy-rs -- .#linode-us
```

- Point all public A records at `45.33.39.244`, drop the ones at `5.223.55.249`.
- cert-manager re-issues via ACME HTTP-01 **through the proxy** (DNS → linode →
  homelab → traefik); confirm with `kubectl get certificate -A`.
- Verify externally: `curl -v https://<domain>` from a non-LAN network.

## Phase 5 — clients

```sh
# New kubeconfig: copy homelab's k3s.yaml, repoint at the tailnet
ssh homelab 'sudo cat /etc/rancher/k3s/k3s.yaml' | \
  sed 's|server: https://.*:6443|server: https://100.89.132.36:6443|' | sudo tee ~/.kube/config
kubectl get nodes   # through the tailnet, no hetzner anywhere
```

- SMB (`code-stash`) remounts itself via the launchd watchdog — verify
  `mount | grep code-stash` after a few minutes.
- Prometheus scrape targets (node-exporter) now point at homelab.

## Phase 6 — decommission hetzner in the repo

Only after phases 4–5 are verified:

```sh
git rm -r hosts/hetzner secrets/hetzner.yaml
# modules/nixos.nix: drop the hetzner-sg nixosConfiguration
# output.nix:       drop deploy.nodes.hetzner-sg
# .sops.yaml:       drop &hetzner_age from keys AND from the creation rule
sops updatekeys secrets/homelab.yaml     # rebind homelab.yaml to admin+homelab only
```

Then **rotate** anything hetzner's age key could still decrypt (it was a
recipient of `homelab.yaml`): `smb-password`, and if in doubt the k3s token
(now single-member, token is just an artifact). `nix flake check`, then cancel
the VPS in the Hetzner console — the old cluster object disappears with it.

## Rollback & emergency

| Point of failure | Rollback |
| --- | --- |
| Join fails (etcd handshake, timeouts) | Hetzner untouched — delete the half-joined node on homelab, redeploy agent config, cluster never changed. |
| 2-member window: hetzner dies early | Restore from snapshot on homelab: `k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>` (emergency; documented k3s path). |
| Member removal fails | Still 2/2 or 1/2 — never stop the second member. Re-run with both healthy, or restore snapshot. |
| Data copy of the 2 hetzner PVs incomplete | Hetzner still running until phase 6 — re-run the tar/rsync. |

## Gotchas

| Trap | Symptom | Fix |
| --- | --- | --- |
| Killing hetzner before member removal | etcd no quorum (1/2), API hangs | Members must be removed while 2/2 are healthy (Phase 2 order) |
| `clusterInit = true` on the joining server | second node tries to init its own etcd | First member only; joiners use `serverAddr` (documented in the k3s module) |
| Forgetting 2379/2380 on homelab | etcd peering timeouts on join | Open both TCP ports (peer/client) on the wg iface |
| Deploying the *final* config first | wireguard gone mid-migration, etcd mesh broken | Phase-1 joining config keeps wg + token + serverAddr; final config only after Hetzner removed |
| Node `homelab` deleted during join | all its pods strand Pending | Leave the node object; kubelet re-registers in place |
| Snapshot left only on hetzner | rollback point dies with the VPS | Copy to macair/homelab in Phase 0 |
| `k3s etcd …` subcommands assumed | "No help topic for 'etcd'" (k3s 1.35 here) | Use `k3s etcd-snapshot save` + etcdctl (via `nix shell nixpkgs#etcd`) for member ops |

## Final verification checklist

- [ ] `kubectl get nodes` → one node, `homelab`, Ready (control-plane), via `https://100.89.132.36:6443`
- [ ] `kubectl get pv,pvc -A` → all Bound, the 2 migrated volumes included
- [ ] `kubectl get pods -A` → no CrashLoop/Pending; apps serve content
- [ ] `curl -v https://<domain>` through linode → traefik cert valid
- [ ] SMB mount up, prometheus scraping homelab
- [ ] `k3s etcd-snapshot ls` on homelab → routine snapshots scheduled
- [ ] hetzner gone from repo, `.sops.yaml`, and the console
