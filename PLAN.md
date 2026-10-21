# Handoff — `homelab-n150` rename + `homelab-3070` install

> **STATUS: EXECUTED 2026-10-20.** All eight phases are complete: the host is
> `homelab-n150` (k8s node name still `homelab`), Determinate Nix is on every
> NixOS host, and `homelab-3070` is a Ready k3s agent. Execution record and
> deviations from this plan (blocked `kexec`, tmpfs installer store, stale
> Proxmox LVM signature, DHCP address change) are in
> [`docs/install-nixos-on-homelab-3070.md`](docs/install-nixos-on-homelab-3070.md).
> The text below is left as the pre-execution handoff.

**Status:** analysis complete, ready to execute
**Date:** 2026-10-20
**Scope:** rename current `homelab` → `homelab-n150`, install the old Alpine box as `homelab-3070`, join it to the existing k3s cluster as an agent, and roll Determinate Nix out to every NixOS host.

> The previous `PLAN.md` (dendritic refactor) is preserved in git history at `HEAD:PLAN.md`.

---

## 0. Confirmed decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Old Alpine data | **Wipe** — confirmed by user |
| 2 | New node role | **k3s agent/worker**, not a second etcd/server |
| 3 | Existing k3s node name | **Keep `homelab`** via `--node-name=homelab`; rename OS/Tailscale/deploy to `homelab-n150` |
| 4 | Tailscale login | **Interactive**, same as existing hosts |
| 5 | N150 deploy | **root key auth** + `interactiveSudo = false`; passwordless (root key already installed) |
| 6 | Partitioning | **disko** |
| 7 | Determinate Nix | **All NixOS hosts** — `homelab-n150`, `linode-us`, `homelab-3070` |
| 8 | N150 root filesystem | ext4 (simple, low-RAM); no hibernation `resumeDevice` |
| 9 | 3070 phase-1 install | **No sops, no k3s**; add them after the real SSH host key exists |

### Names

| Old | New |
|---|---|
| host dir `hosts/homelab` | `hosts/homelab-n150` |
| NixOS config `homelab` | `homelab-n150` |
| deploy node `homelab` | `homelab-n150` |
| Tailscale name `homelab` | `homelab-n150` |
| k3s node name `homelab` | **stays `homelab`** |
| new host | `homelab-3070`, k3s node `homelab-3070` |

---

## 1. Hard constraints from the analysis

1. **49 PVs are pinned to `homelab`.** The N150 is the only etcd member. Flipping `networking.hostName` without adding `--node-name=homelab` would rename the k8s node and orphan every PV. The rename is therefore split into two deploys (SR-1 then SR-2).
2. **PV `nodeAffinity` is immutable.** A full k3s node rename would require deleting/recreating all 49 PVs, moving data out of `reclaimPolicy: Delete` directories, and risking the single etcd member. **Not doing it.** `kubectl get nodes` will intentionally show `homelab` + `homelab-3070`.
3. **Any client resolving `homelab` outside MagicDNS may land on the old Alpine box at `192.168.1.194`.** Bare `homelab` currently works because MagicDNS is searched first; after the Tailscale rename it can silently fall through. `kubectl` is already IP-pinned; the SMB mount is the only name-based automated client, so it is pinned to the stable tailnet IP `100.89.132.36` **before** any rename.
4. **`--copy-host-keys` is not reliable for preserving the Alpine host key** (it may copy the kexec'd installer's keys). Do not precompute the sops age recipient. Install phase 1 **without sops/k3s**, read the real host key, then enroll it.
5. **disko emits plain `fileSystems`/`swapDevices` definitions.** The new host's `hardware-configuration.nix` must not define them. Do **not** use `--generate-hardware-config`.
6. **Determinate Nix restarts `nix-daemon`.** Keep a second SSH session open. If `determinate-nixd` fails, `nixos-rebuild --rollback` and deploy-rs both fail; recover with the previous system closure's `activate` script.
7. **local-path `config.json` hot-reloads every 30 s.** No restart needed for the ConfigMap change; allow ~90–120 s. `helperPod.yaml` changes *do* need a restart.
8. **`local-path` is capacity-unaware.** Any pod without node affinity can schedule on the 3.8 GB 3070 and bind a large PVC on its 238 GB root disk. Keep large stateful workloads on `local-large`/the N150.

---

## 2. Tailscale login (answer to the auth-key question)

Existing hosts do **not** use auth keys:

- `hosts/homelab/default.nix`: `services.tailscale.enable = true;` only.
- `hosts/linode-us/default.nix`: same, with the comment “First login is interactive: run `tailscale up` on the box and approve the printed URL.”

Flow: `tailscaled` starts unauthenticated → run `tailscale up` → approve the printed URL → login persists in `/var/lib/tailscale/tailscaled.state`. `homelab-3070` follows the same pattern. **No Tailscale secret in sops.**

Keep interactive for now. Auth keys are only worth it for unattended rebuilds; if adopted later, use a reusable, pre-authorized, tagged key in sops and remember initial enrollment is the only thing it covers.

Separate maintenance item: existing node keys expire — `homelab` `2026-11-30`, `linode-us` `2027-03-21`. Disable key expiry for always-on servers in the Tailscale admin console, and for the two new names after enrollment.

---

## 3. Final execution order

| Phase | What | Who |
|---|---|---|
| 0 | Preflight: root SSH (done), safety copies, etcd snapshot, token check, baseline | Agent + user |
| 1 | Pin macair SMB mount to `100.89.132.36` | Agent edits, **[HUMAN]** runs `darwin-rebuild` |
| 2 | **N150 SR-1:** add `--node-name=homelab` only; deploy; verify node identity unchanged | Agent (root SSH) |
| 3 | **Determinate Nix rollout:** linode-us first, then N150 (no rename); verify | Agent (root SSH) |
| 4 | **N150 SR-2:** rename host/config/deploy/Tailscale to `homelab-n150`; deploy; verify 49 PVs Bound | Agent (root SSH) |
| 5 | **Install `homelab-3070`:** disko + NixOS phase 1 (no sops/k3s); verify host key | Agent |
| 6 | Enroll real host key in sops; add k3s agent + Tailscale IP; deploy | Agent |
| 7 | **local-path** ConfigMap for `homelab-3070`; test PVC; cleanup | Agent |
| 8 | Verification, docs, commits | Agent |

N150 deploys use root key auth (`sshUser = "root"`, `user = "root"`, `interactiveSudo = false`). The root key is declared in `hosts/homelab/default.nix` and already installed on the live box. The 3070 deploys use the same pattern.

### 3.1 Orchestrator / interactive sudo

Current state (verified):

```sh
sudo -n true || echo "macair sudo requires a password"
ssh -o BatchMode=yes root@100.89.132.36 'id'   # works; root key is installed
```

- macair: password required for `sudo darwin-rebuild`.
- N150: root SSH works with the macair key. The key is now declared in `hosts/homelab/default.nix` and will survive rebuilds.
- N150 deploys are root/non-interactive: `sshUser = "root"`, `user = "root"`, `interactiveSudo = false`.
- `deploy-rs` `interactiveSudo = true` (if used elsewhere) prompts **locally** with `rpassword::prompt_password` and pipes the password to remote `sudo -S`. N150 no longer uses it.
- `ssh host 'sudo ...'` without `-t` fails with `sudo: a terminal is required`.
- N150 read-only checks are passwordless: `systemctl cat k3s`, `journalctl -u k3s`, `systemctl is-active k3s`.
- Cluster/etcd checks are passwordless from macair: `kubectl`, `kubectl get --raw '/readyz?verbose'`.

**What an orchestrator must do:** stop at `[HUMAN]` steps and ask the user. Do not put a sudo password in the plan, environment, or command line. Do not retry a failed `sudo` prompt.

**[HUMAN] steps:**

- macair `sudo darwin-rebuild switch --flake .`
- Tailscale login URL approval
- Tailscale admin-console actions (node-key expiry)

**Non-interactive steps:** all `kubectl` gates, N150 root-SSH deploys and root-SSH operational commands (`k3s etcd-snapshot save`, `tailscale set --hostname=...`), the root-SSH `homelab-3070` install/deploy, the `linode-us` root deploy, and the N150 read-only `systemctl`/`journalctl` gates.

**Implemented for orchestration:** the N150 deploy node is root/non-interactive, and the root key is declared in the host config. The only remaining local sudo is macair `darwin-rebuild` (one-time SMB pin), which can stay human. If you also want to automate that, use `sudo -A` with a Keychain-backed askpass helper; do not pipe the password.

---

## 4. Worktree / subagent split

Analysis is complete (four read-only reports). Code work:

| Worktree | Branch | Scope |
|---|---|---|
| WT1 | `refactor/homelab-hosts` | All `config.nix` NixOS changes: SMB IP, SR-1/SR-2 rename, Determinate module, new 3070 host, disko input, deploy nodes, README/AGENTS |
| WT2 | `chore/sops-homelab-3070` | `.sops.yaml`, `secrets/homelab-3070.yaml`, `secrets/README.md` — **after** phase 5 produces the real host key |
| WT3 | `chore/local-path-homelab-3070` | `~/code/homelab-helm/services/local-path-storage/standalone.yml` |
| WT4 | `docs/install-homelab-3070` | New install runbook, historical-doc banners |

WT2 is no longer parallel with the install; its age recipient comes from the installed host. WT4 merges after WT1. Live/destructive commands run sequentially in the main agent; subagents may only read/verify during live phases.

---

## 5. Phase 0 — preflight

### 5.1 Root SSH (already done)

Verified: `ssh -p 2222 root@192.168.1.194 id` returns `uid=0(root)`.

### 5.2 Safety copies before wipe

User confirmed the 142 GB is disposable. Copy the small irreplaceable bits:

```sh
mkdir -p ~/backups/old-homelab-3070
scp -P 2222 -r napatsc@192.168.1.194:/home/napatsc/.ssh ~/backups/old-homelab-3070/
scp -P 2222 -r napatsc@192.168.1.194:/home/napatsc/services ~/backups/old-homelab-3070/services-configs
```

Optional: record the Alpine host-key fingerprint (for comparison after install even though we will accept new keys):

```sh
ssh-keyscan -p 2222 192.168.1.194 2>/dev/null | ssh-keygen -lf -
```

### 5.3 Baseline cluster state

```sh
kubectl get nodes -o wide
kubectl get node homelab -o jsonpath='{.metadata.uid}{"\n"}{.metadata.labels.kubernetes\.io/hostname}{"\n"}'
kubectl get pv -o json | jq -r '[.items[].spec.nodeAffinity.required.nodeSelectorTerms[]?.matchExpressions[]? | select(.key=="kubernetes.io/hostname") | .values[]] | group_by(.) | map({node:.[0], count:length})'
kubectl get pv -o json | jq -r '.items[] | "\(.metadata.name) \(.metadata.uid) \(.status.phase)"' | sort > /tmp/pv-before.txt
kubectl get pvc -A --no-headers | awk '$3 != "Bound" {print $1"/"$2}' | sort > /tmp/pvc-pending-before.txt
wc -l < /tmp/pvc-pending-before.txt   # expect 5: homelab/{consume,data,db-data,export,media}
kubectl get pv -o json | jq -r '.items[] | select(.status.phase != "Bound") | .metadata.name'
```

Expected: one node `homelab`, 49 PVs pinned to `homelab`, 5 pre-existing Pending PVCs in namespace `homelab` (WFFC, no pods), no unbound PVs.

### 5.4 etcd snapshot

```sh
ssh root@100.89.132.36 'k3s etcd-snapshot save && k3s etcd-snapshot ls | tail -3'
```

### 5.5 Verify the k3s token

```sh
nix run nixpkgs#sops -- -d --extract '["k3s-token"]' secrets/homelab.yaml | wc -c
```

If the join later fails with auth errors, recover the live token with a privileged pod:

```sh
kubectl debug node/homelab -it --image=alpine -- \
  cat /host/var/lib/rancher/k3s/server/token
```

Only if needed; delete the debug pod afterwards.

### 5.6 Verify eval and `extraFlags` type

```sh
nix flake check
nix eval --raw .#nixosConfigurations.homelab.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.linode-us.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.homelab.config.systemd.services.k3s.serviceConfig.ExecStart \
  | tr ' ' '\n' | grep -E 'node-name|tls-san|node-ip|flannel'
```

Both existing configs currently evaluate (the `vars` argument in `hardware-configuration.nix` is harmless). Do **not** copy `vars` to the new host.

### 5.7 Verify the macair x86_64 builder

All `deploy-rs` and `nixos-anywhere --build-on local` runs need macair's `linux-builder`. Check it before orchestration:

```sh
nix build --dry-run .#nixosConfigurations.homelab.config.system.build.toplevel 2>&1 | tail -5
```

If it fails with `failed to start SSH master connection to 'linux-builder'` or hangs on `vsock:22 not ready`, restart the builder (macair sudo, human):

```sh
sudo launchctl kickstart -k system/org.nixos.linux-builder
# or, if that does not recover it:
sudo launchctl bootout system/org.nixos.linux-builder
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.linux-builder.plist
```

Fallbacks: set `remoteBuild = true` on the deploy node (builds on the target), or use `nixos-anywhere --build-on remote` for the 3070 install. Remote build on the 3.8 GB 3070 is memory-constrained; prefer fixing the macair builder.

---

## 6. Phase 1 — pin macair SMB to the tailnet IP

Edit `users/napatsc/default.nix` around line 118:

```nix
/sbin/mount_smbfs "//samba:''${pw}@100.89.132.36:30445/code-stash" "$mountpoint"
```

Update the log string to something host-neutral (`code-stash host unreachable`). Keep `sopsFile = ../../secrets/homelab.yaml` unchanged.

Then on macair:

```sh
git add users/napatsc/default.nix
sudo darwin-rebuild switch --flake .
mount | grep code-stash
tail -20 /tmp/smb-code-stash.log
```

This is behaviourally a no-op today (MagicDNS already yields `100.89.132.36`) and removes the only automated DNS-dependent client before the rename.

---

## 7. Phase 2 — N150 SR-1: pin the k3s node name

**Do not rename the host yet.** Add only this flag to `hosts/homelab/default.nix` (`extraFlags`):

```nix
"--node-name=homelab"   # pin k8s/etcd identity: 49 PVs + embedded etcd depend on it
```

Keep the existing flags unchanged (`--tls-san=homelab`, `--tls-san=100.89.132.36`, `--node-ip`, `--flannel-iface`, snapshot cron, etc.).

Pre-flight:

```sh
git add hosts/homelab/default.nix
nix eval --raw .#nixosConfigurations.homelab.config.systemd.services.k3s.serviceConfig.ExecStart \
  | tr ' ' '\n' | grep -F -- '--node-name=homelab'
```

Deploy (agent runs; root SSH, no sudo):

```sh
nix run github:serokell/deploy-rs -- .#homelab
```

Gate:

```sh
kubectl get nodes -o wide          # NAME must still be `homelab`
kubectl get node homelab -o jsonpath='{.metadata.uid}{"\n"}'   # same UID as baseline
kubectl get pv -o json | jq -r '.items[] | "\(.metadata.name) \(.metadata.uid) \(.status.phase)"' | sort > /tmp/pv-after-sr1.txt
diff /tmp/pv-before.txt /tmp/pv-after-sr1.txt && echo "PVs unchanged"
kubectl get pvc -A --no-headers | awk '$3 != "Bound" {print $1"/"$2}' | sort > /tmp/pvc-pending-after-sr1.txt
diff /tmp/pvc-pending-before.txt /tmp/pvc-pending-after-sr1.txt && echo "pending PVC set unchanged"
kubectl get pv -o json | jq -r '.items[] | select(.status.phase != "Bound") | .metadata.name'
ssh napatsc@100.89.132.36 'systemctl cat k3s | grep -o -- "--node-name=[^ ]*"; systemctl is-active k3s; journalctl -u k3s -n 50 | grep -i "unknown flag\|failed" || true'
```

If the node name moved: revert the flag and redeploy immediately; the hostname was never changed, so the cluster identity should return to `homelab`.

---

## 8. Phase 3 — Determinate Nix rollout

Add one line to the shared module list in `modules/nixos.nix`:

```nix
inputs.determinate.nixosModules.default
```

Keep `inputs.nixpkgs.follows = "nixpkgs"` on the determinate input. The module is on by default (`determinate.enable = true`); no extra option is needed.

### Rollout order

1. **linode-us** (least critical, serial console rescue):
   ```sh
   git add modules/nixos.nix
   nix run github:serokell/deploy-rs -- .#linode-us
   ```
   Keep a second SSH session open. Verify:
   ```sh
   ssh root@45.33.39.244 'nix --version; systemctl is-active nix-daemon; systemctl --failed; nix config show | grep -E "^(substituters|trusted-users|trusted-public-keys|auto-optimise-store)"'
   ```
2. **homelab** (no rename yet; agent runs the deploy over root SSH):
   ```sh
   nix run github:serokell/deploy-rs -- .#homelab
   ```
   Verify:
   ```sh
   ssh napatsc@100.89.132.36 'nix --version; systemctl is-active nix-daemon; systemctl is-active k3s; nix config show | grep builders-use-substitutes; systemctl --failed'
   ```
   Confirm `builders-use-substitutes` is `false` and `nix.custom.conf` still contains the repo settings.
3. **homelab-3070** gets Determinate from its first install.

### Recovery if `determinate-nixd` fails

Do **not** use `nixos-rebuild --rollback` (it needs the daemon). Use the previous system closure's activation script:

```sh
ssh root@<host>   # or Linode Lish / physical console
ls /nix/var/nix/profiles/system-*-link
/nix/var/nix/profiles/system-<N-1>-link/activate
```

Then revert the module line and redeploy.

Notes:

- Determinate moves the NixOS-generated config to `/etc/nix/nix.custom.conf`; existing `nix.settings` survive there.
- The NixOS module exposes no GC knob in 3.22/3.23, so NixOS `nix.gc` and `determinate-nixd` maintenance may both run. Accept for now; watch `journalctl -u nix-daemon -g gc`.
- Re-read the locked module before deploying if the lock changed:
  `nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.determinate.outPath'`, then read `<outPath>/modules/nixos.nix`.

---

## 9. Phase 4 — N150 SR-2: rename host/Tailscale/deploy

Now rename the identity, with the node-name pin already proven.

```sh
git mv hosts/homelab hosts/homelab-n150
```

`modules/nixos.nix` → `homelab-n150` config (use named-arg `mkHost`, see §10.1; the signature change and call-site updates must land in the same commit).
`output.nix` → deploy node `homelab-n150`, `hostname = "100.89.132.36"` (stable; do not depend on MagicDNS during the deploy), `sshUser = "root"`, `user = "root"`, `interactiveSudo = false`.
**Keep `secrets/homelab.yaml` unchanged** — do not rename it to `homelab-n150.yaml`; `defaultSopsFile` must stay `../../secrets + "/homelab.yaml"` (the relative depth is unchanged by `git mv`).
Replace the stale comment in `hosts/homelab-n150/default.nix` that says the k3s token was dropped: `secrets/homelab.yaml` still holds `k3s-token`, `smb-password`, and legacy wireguard keys.
`hosts/homelab-n150/default.nix`:

```nix
networking.hostName = "homelab-n150";
services.k3s.extraFlags = [
  "--node-name=homelab"
  "--tls-san=homelab"          # keep for old-name clients
  "--tls-san=homelab-n150"     # new name
  "--tls-san=100.89.132.36"
  # ...existing flags unchanged
];
```

Update current-state docs/tables: `README.md`, `AGENTS.md`, `secrets/README.md`, comments in `hosts/linode-us/default.nix`. Add a one-line banner to `docs/control-plane-migration*.md` that “homelab” is now `homelab-n150` in the repo/Tailscale; do not rewrite history.

Deploy (agent runs; root SSH, no sudo):

```sh
git add -A
nix flake check
nix eval --raw .#nixosConfigurations.homelab-n150.config.system.build.toplevel.drvPath
nix run github:serokell/deploy-rs -- .#homelab-n150
```

Gate:

```sh
kubectl get nodes -o wide           # still exactly `homelab` (same UID)
kubectl get pv -o json | jq -r '.items[] | "\(.metadata.name) \(.metadata.uid) \(.status.phase)"' | sort > /tmp/pv-after-sr2.txt
diff /tmp/pv-before.txt /tmp/pv-after-sr2.txt && echo "PVs unchanged"
kubectl get pvc -A --no-headers | awk '$3 != "Bound" {print $1"/"$2}' | sort > /tmp/pvc-pending-after-sr2.txt
diff /tmp/pvc-pending-before.txt /tmp/pvc-pending-after-sr2.txt && echo "pending PVC set unchanged"
kubectl get pv -o json | jq -r '.items[] | select(.status.phase != "Bound") | .metadata.name'
ssh napatsc@100.89.132.36 'hostname; systemctl is-active k3s; systemctl is-active sops-install-secrets'
kubectl -n kube-system get secret k3s-serving -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | sed -n '/Subject Alternative Name/,+1p'
```

The SAN list must include `homelab`, `homelab-n150`, and `100.89.132.36`.

Then rename Tailscale:

```sh
ssh root@100.89.132.36 'tailscale set --hostname=homelab-n150'
tailscale status | grep -E 'homelab|linode'
host homelab-n150.tail47fb71.ts.net
ssh -o BatchMode=yes homelab-n150 'hostname; tailscale status --self | head -1'
```

Clean up the old host-key alias:

```sh
ssh-keygen -R homelab
```

SMB is already pinned to the IP, so it should not notice the rename. Verify `mount | grep code-stash` after the deploy.

---

## 10. Phase 5 — install NixOS on `homelab-3070`

### 10.1 Repo scaffolding

`flake.nix` input:

```nix
disko = {
  url = "github:nix-community/disko";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

If disko’s own flake lib breaks against this nixpkgs snapshot, drop `follows` for disko only. Do not change the Determinate `follows`.

`modules/nixos.nix`:

```nix
mkHost = { host, extraModules ? [ ] }:
  inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { user = config.user; };
    modules = [
      (rootPath + "/hosts/${host}")
      inputs.sops-nix.nixosModules.sops
      inputs.determinate.nixosModules.default
      config.nixos.modules.base
      config.nixos.modules.identity
    ] ++ extraModules;
  };

config.flake.nixosConfigurations.homelab-n150 = mkHost { host = "homelab-n150"; };
config.flake.nixosConfigurations.linode-us = mkHost { host = "linode-us"; };
config.flake.nixosConfigurations.homelab-3070 = mkHost {
  host = "homelab-3070";
  extraModules = [ inputs.disko.nixosModules.disko ];
};
```

`hosts/homelab-3070/disk-config.nix`:

```nix
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";   # VERIFY with lsblk before install
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        swap = {
          size = "8G";
          content = { type = "swap"; };   # no resumeDevice / hibernation
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
```

`hosts/homelab-3070/hardware-configuration.nix` — **no `fileSystems`, no `swapDevices`, no `vars`**:

```nix
{ lib, config, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
```

`hosts/homelab-3070/default.nix` phase 1 (no sops, no k3s, firewall only SSH):

```nix
{ user, config, lib, ... }:
{
  imports = [ ./hardware-configuration.nix ./disk-config.nix ];

  system.stateVersion = "26.11";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homelab-3070";
  networking.enableIPv6 = true;

  nix.settings.builders-use-substitutes = lib.mkForce false;

  users.users.${user.username}.linger = true;
  users.users.root.openssh.authorizedKeys.keys = [ user.sshKey ];

  services.openssh = {
    enable = true;
    restartIfChanged = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.tailscale.enable = true;

  services.k3s.enable = false;   # enabled in phase 6 after the tailnet IP is known
}
```

`output.nix`:

```nix
deploy.nodes.homelab-3070 = {
  hostname = "<3070-tailnet-ip>";                 # first deploy by IP; switch to homelab-3070 after MagicDNS is verified
  sshOpts = [ "-o" "StrictHostKeyChecking=accept-new" ];
  interactiveSudo = false;
  profiles.system = {
    sshUser = "root";
    user = "root";
    path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.homelab-3070;
  };
};
```

Pre-flight:

```sh
nix flake lock      # expect only `disko` added; no nixpkgs/determinate movement
git add -A
nix flake check     # NOTE: this does not check x86_64-linux/deploy outputs on macair
nix eval --raw .#nixosConfigurations.homelab-n150.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.homelab-3070.config.system.build.toplevel.drvPath
nix eval --json .#nixosConfigurations.homelab-3070.config.fileSystems   # disko only
nix eval --raw .#nixosConfigurations.homelab-3070.config.system.build.diskoScript.drvPath
nix build --dry-run .#nixosConfigurations.homelab-3070.config.system.build.toplevel 2>&1 | tail -5
# no `will be built: ...nix-3...` line: Determinate's x86_64 Nix should be substitutable
```

### 10.2 Install

Target preflight:

```sh
ssh -p 2222 root@192.168.1.194 '
  lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINT
  ls /sys/firmware/efi | head
  free -m
  command -v kexec || ls -l /sbin/kexec || echo NO_KEXEC
'
ssh-keygen -R '[192.168.1.194]:2222'
# Confirm a DHCP reservation or record the Alpine MAC; if the address changes after install,
# find the new one via the router / `arp -a`.
nix path-info -S .#nixosConfigurations.homelab-3070.config.system.build.toplevel | tail -1
```

Expect exactly one 238 GB NVMe (`nvme0n1`). If `kexec` is missing, install `kexec-tools` via Alpine or use a NixOS USB installer.

Install command — **no `--copy-host-keys`, no `--generate-hardware-config`**:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#homelab-3070 \
  --target-host root@192.168.1.194 \
  --ssh-port 2222 \
  --build-on local \
  --ssh-option UserKnownHostsFile=/dev/null \
  --ssh-option StrictHostKeyChecking=no \
  --debug
```

Why:

- `--ssh-port 2222` is the pre-kexec Alpine port; the kexec'd installer listens on 22 and nixos-anywhere handles that separately.
- `--build-on local` builds on macair's linux-builder; the 3.8 GB target only runs `nixos-install`.
- disko wipes and partitions the NVMe.
- Phase 1 has no sops/k3s, keeping the installer closure and first-boot failure surface small.
- If the installer runs out of RAM (`ENOSPC`/OOM during the closure copy), re-run with `--no-disko-deps`. If it still fails, use a NixOS USB installer and `--phases disko,install`.

After reboot:

```sh
ssh -o StrictHostKeyChecking=accept-new root@192.168.1.194 'hostname; cat /etc/os-release | head -2; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT; df -h / /boot; free -m; systemctl --failed'
ssh root@192.168.1.194 'ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub'
```

Record the **real** host key. If DNS/SSH is unreachable, use the console; do not rerun disko.

---

## 11. Phase 6 — enroll host key, Tailscale, and k3s agent

### 11.1 Sops recipient from the real host key

```sh
ssh root@192.168.1.194 'cat /etc/ssh/ssh_host_ed25519_key.pub' \
  | nix run nixpkgs#ssh-to-age
```

Add that age key to `.sops.yaml` with a **new** rule (the existing `homelab\.yaml$` rule is anchored and will not match `homelab-3070.yaml`):

```yaml
- path_regex: homelab-3070\.yaml$
  key_groups:
    - age:
        - *admin_age
        - &homelab_3070_age age1...
```

Create `secrets/homelab-3070.yaml` with the existing k3s token, encrypted to admin + the new host. Do not print the token:

```sh
umask 077
nix run nixpkgs#sops -- -d --extract '["k3s-token"]' secrets/homelab.yaml \
  | sed 's/^/k3s-token: /' > /tmp/k3s-token.yaml
nix run nixpkgs#sops -- encrypt --filename-override secrets/homelab-3070.yaml \
  --output secrets/homelab-3070.yaml /tmp/k3s-token.yaml
rm -f /tmp/k3s-token.yaml
```

Verify (token shape and length, without printing):

```sh
nix run nixpkgs#sops -- -d --extract '["k3s-token"]' secrets/homelab-3070.yaml \
  | tee /tmp/token-check | grep -q '^K10' && wc -c < /tmp/token-check
rm -f /tmp/token-check
```

### 11.2 Tailscale

```sh
ssh -t root@192.168.1.194 'tailscale up'   # approve printed URL
ssh root@192.168.1.194 'tailscale status; tailscale ip -4'
```

Record the tailnet IPv4.

### 11.3 Enable sops + k3s agent

Add to `hosts/homelab-3070/default.nix`:

```nix
sops = {
  defaultSopsFile = ../../secrets + "/homelab-3070.yaml";
  defaultSopsFormat = "yaml";
  age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.generateKey = true;
  age.keyFile = "/var/lib/sops-nix/key.txt";
};
sops.secrets.k3s-token = { };

services.k3s = {
  enable = true;
  role = "agent";
  serverAddr = "https://100.89.132.36:6443";
  tokenFile = config.sops.secrets.k3s-token.path;
  extraFlags = [
    "--node-name=homelab-3070"
    "--node-ip=<tailnet-ip>"
    "--node-external-ip=<tailnet-ip>"
    "--flannel-iface=tailscale0"
    "--node-label=storage-tier=nvme"
  ];
};
systemd.services.k3s.after = [ "tailscaled.service" "sops-install-secrets.service" ];
systemd.services.k3s.wants = [ "tailscaled.service" ];

networking.firewall = {
  # Same exposure as the N150. If you want LAN-only SSH, move 9100/10250
  # to interfaces.tailscale0.allowedTCPPorts instead.
  allowedTCPPorts = [ 9100 10250 ];
  allowedUDPPorts = [ 8472 41641 ];
  interfaces.tailscale0 = {
    allowedTCPPorts = [ 31557 32724 ];
    allowedUDPPorts = [ 31999 ];
  };
};

systemd.services."k3s-storage-dirs" = {
  description = "Ensure k3s local-path storage directory exists";
  serviceConfig.Type = "oneshot";
  script = "mkdir -p /var/lib/rancher/k3s/storage";
  wantedBy = [ "multi-user.target" ];
};
```

Before deploying, establish host-key trust for the tailnet IP:

```sh
ssh -o StrictHostKeyChecking=accept-new root@<3070-tailnet-ip> true
```

Deploy:

```sh
git add -A
nix run github:serokell/deploy-rs -- .#homelab-3070
```

Verify:

```sh
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
kubectl get pvc -A --no-headers | awk '$3 != "Bound" {print $1"/"$2}' | sort > /tmp/pvc-pending-after-join.txt
diff /tmp/pvc-pending-before.txt /tmp/pvc-pending-after-join.txt && echo "pending PVC set unchanged"
kubectl get pv -o json | jq -r '.items[] | select(.status.phase != "Bound") | .metadata.name'
ssh root@<3070-tailnet-ip> 'systemctl is-active k3s; systemctl --failed; ip -br a | grep tailscale0'
```

If the join fails with auth errors, the sops token is stale: recover the live token via §5.5, update `secrets/homelab-3070.yaml`, redeploy.

---

## 12. Phase 7 — local-path storage for `homelab-3070`

Edit `~/code/homelab-helm/services/local-path-storage/standalone.yml` (`config.json` only):

```json
{
  "nodePathMap": [
    { "node": "homelab-3070", "paths": ["/var/lib/rancher/k3s/storage"] },
    { "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES", "paths": ["/mnt/fast"] }
  ]
}
```

Update the manifest, then verify the diff before applying. The repo’s `kustomization.yml` is dirty, and applying the whole file also re-applies the Deployment and StorageClass:

```sh
cd ~/code/homelab-helm
kubectl diff -f services/local-path-storage/standalone.yml   # expect only the config.json hunk
```

Preferred: patch only the ConfigMap.

```sh
cat > /tmp/local-path-config.json <<'EOF'
{
  "nodePathMap": [
    { "node": "homelab-3070", "paths": ["/var/lib/rancher/k3s/storage"] },
    { "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES", "paths": ["/mnt/fast"] }
  ]
}
EOF
kubectl -n kube-system patch cm local-path-config --type=merge \
  -p "$(jq -Rn --arg c "$(cat /tmp/local-path-config.json)" '{data:{"config.json":$c}}')"
kubectl -n kube-system get cm local-path-config -o jsonpath='{.data.config\.json}'; echo
```

`nodePathMap[].node` matches the **k8s node name**. The N150 entry is intentionally omitted because `DEFAULT_PATH_FOR_NON_LISTED_NODES` covers it; if ever added explicitly it must say `homelab`, never `homelab-n150`.

No restart needed for `config.json`; the provisioner polls every 30 s. Wait ~90–120 s before testing. If you *do* restart (optional), use:

```sh
kubectl -n kube-system rollout restart deploy/local-path-provisioner-standalone
kubectl -n kube-system rollout status deploy/local-path-provisioner-standalone --timeout=120s
```

Test (save the manifest below as `/tmp/smoke-3070.yaml`; the PVC delete triggers the disposable `rm -rf` teardown):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: smoke-3070
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 10Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: smoke-3070
spec:
  nodeSelector:
    kubernetes.io/hostname: homelab-3070
  restartPolicy: Never
  containers:
    - name: sh
      image: busybox:1.37.0
      command: ["sh", "-c", "echo ok > /data/ok && cat /data/ok && sleep 300"]
      volumeMounts:
        - { name: data, mountPath: /data }
  volumes:
    - name: data
      persistentVolumeClaim: { claimName: smoke-3070 }
```

```sh
kubectl apply -f /tmp/smoke-3070.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/smoke-3070 --timeout=180s
PV=$(kubectl get pvc smoke-3070 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o jsonpath='{.spec.hostPath.path}{"\n"}{.metadata.annotations.local\.path\.provisioner/selected-node}{"\n"}'
kubectl exec smoke-3070 -- cat /data/ok
kubectl delete pod smoke-3070 --ignore-not-found
kubectl delete pvc smoke-3070 --ignore-not-found
```

Expected path: `/var/lib/rancher/k3s/storage/pvc-<uid>_default_smoke-3070`, selected node `homelab-3070`.

Safety notes:

- Do **not** label `homelab-3070` with `storage-tier=large`; `local-large` must stay on the N150 HDD.
- `local-path` is capacity-unaware; keep large stateful workloads on `local-large` or pin them to the N150.
- `local-path-config-standalone` is an orphan; do not wire it up (`"node": "*"` is not a wildcard).
- Five PVCs in namespace `homelab` have been pending for 77 days; they can bind on the 3070 when a pod consumes them. Review/clean them up separately.
- Both tiers use `reclaimPolicy: Delete` + `rm -rf` teardown; never delete an unfamiliar PVC casually.

---

## 13. Phase 8 — verification / definition of done

- [ ] `kubectl get nodes -o wide` → `homelab` Ready control-plane/etcd, `homelab-3070` Ready agent
- [ ] `kubectl get node homelab` UID unchanged; `kubernetes.io/hostname=homelab`
- [ ] `kubectl get pv -o json | jq -r '.items[] | select(.status.phase != "Bound") | .metadata.name'` → empty
- [ ] Pending PVC set unchanged: `kubectl get pvc -A --no-headers | awk '$3 != "Bound" {print $1"/"$2}' | sort | diff /tmp/pvc-pending-before.txt -` (5 known in namespace `homelab`)
- [ ] `kubectl get pods -A | grep -vE 'Running|Completed'` → empty
- [ ] etcd health: `kubectl get --raw '/readyz?verbose' | grep 'etcd ok'` (k3s embedded etcd has no pod; no host sudo needed)
- [ ] Optional: etcd member list unchanged via `ssh root@100.89.132.36 '/run/current-system/sw/bin/nix shell nixpkgs#etcd -c etcdctl ... member list'` (root SSH, no sudo)
- [ ] `k3s-serving` SANs include `homelab`, `homelab-n150`, `100.89.132.36`
- [ ] `kubectl get ds -A -o wide` → node-exporter/svclb/NFD `DESIRED=2` (Intel GPU only if NFD labels the iGPU)
- [ ] `kubectl -n default get endpoints prometheus-prometheus-node-exporter` includes both node IPs
- [ ] Cross-node pod network: busybox pods on each node; `kubectl exec p3070 -- ping -c3 -M do -s 1150 <pn150-pod-ip>`
- [ ] `kubectl get node homelab-3070 --show-labels` → `storage-tier=nvme`, never `large`; a `local-large` PVC pinned to `homelab-3070` stays `Pending`
- [ ] `tailscale status` shows `homelab-n150` and `homelab-3070`; `ssh homelab-n150` works
- [ ] `mount | grep code-stash` on macair works; no new timeouts
- [ ] `nix --version` reports Determinate Nix on all NixOS hosts
- [ ] `nix config show` on each host shows `substituters`, `trusted-users`, `trusted-public-keys`, `auto-optimise-store`; N150 shows `builders-use-substitutes = false`
- [ ] `systemctl --failed` clean on both NixOS hosts; `systemctl is-active sops-install-secrets` active on `homelab-3070`
- [ ] `nix flake check` plus per-config evals for `homelab-n150` and `homelab-3070`; WT1–WT4 merged; `git status` clean
- [ ] `docs/install-nixos-on-homelab-3070.md` added with actual commands/incidents

Cross-node pod network check (VXLAN over Tailscale has never had a second node):

```sh
kubectl get node homelab-3070 -o wide          # INTERNAL-IP must be the tailnet IP
kubectl run p3070 --image=busybox:1.37 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"homelab-3070"}}}' -- sleep 600
kubectl run pn150 --image=busybox:1.37 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"homelab"}}}' -- sleep 600
PODIP=$(kubectl get pod pn150 -o jsonpath='{.status.podIP}')
kubectl exec p3070 -- ping -c3 -M do -s 1150 "$PODIP"
kubectl delete pod p3070 pn150 --ignore-not-found
```

---

## 14. Rollback

| Failure | Rollback |
|---|---|
| N150 node name changed in SR-1 | Revert the `--node-name` commit and redeploy while hostname is still `homelab`; node identity returns. |
| N150 rename breaks a client | SMB is already IP-based; use `100.89.132.36` for SSH/deploy. Revert the SR-2 commit and redeploy if needed. |
| Determinate `nix-daemon` fails | Use the previous closure: `ssh root@<host> '/nix/var/nix/profiles/system-<N-1>-link/activate'`. Then revert the module line and redeploy. Do not rely on `nixos-rebuild --rollback`. |
| 3070 install fails after disko | Old Alpine is gone; retry nixos-anywhere or use a NixOS USB installer. No cluster impact. |
| 3070 sops key mismatch | Add the real host age key, `sops updatekeys secrets/homelab-3070.yaml`, redeploy. |
| 3070 k3s join fails | Keep k3s disabled; fix token/IP/firewall; redeploy. Existing cluster untouched. |
| local-path provisioning fails on 3070 | Revert `local-path-config` and restart the provisioner; move test PVCs back to the N150. |
| Tailscale name wrong after SR-2 | `ssh root@100.89.132.36 'tailscale set --hostname=homelab'` (or `--hostname=""` to follow the OS hostname) and verify MagicDNS before changing clients again. |
| 3070 joins but is NotReady | Check flannel/MTU/tailnet reachability first (§13 cross-node test); keep k3s enabled but cordon the node, fix `--node-ip`/`--flannel-iface`/firewall, then uncordon. |
| 3070 must be decommissioned | Cordon/drain first, delete bound PVCs/PVs intentionally, `kubectl delete node homelab-3070`, then remove its `config.json` entry. Deleting a node while a local-path PV is bound orphans that PV. |
| deploy-rs reports failure after a successful activation | deploy-rs `magicRollback` may already have reverted the system; check `kubectl get nodes` / the host before manually rolling back. |
| Full k8s node rename is ever attempted | Do not. PV `nodeAffinity` is immutable and the single etcd member name is derived from the node name. It requires deleting/recreating 49 PVs, moving data, and etcd snapshot/restore. Not worth the cosmetic gain. |

---

## 15. Exact user actions required

Execute in the order of §3 (this is a checklist, not a separate sequence). Items marked **[HUMAN]** require a TTY/password or browser; an orchestrator must pause and ask the user.

1. **[HUMAN]** Run `sudo darwin-rebuild switch --flake .` on macair after the SMB IP change (§6) — prerequisite for the rename.
2. Agent: N150 **SR-1** deploy (root SSH, no sudo).
3. Agent: `linode-us` Determinate deploy; verify.
4. Agent: N150 Determinate deploy (root SSH).
5. Agent: N150 **SR-2** rename deploy (root SSH).
6. Agent: `ssh root@100.89.132.36 'tailscale set --hostname=homelab-n150'`.
7. **[HUMAN]** Approve the Tailscale login URL for `homelab-3070` (§11.2).
8. **[HUMAN]** Disable Tailscale node-key expiry in the admin console (§2).

Everything else can be executed by the agent.
