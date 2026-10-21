# Installing NixOS on `homelab-3070` (disko + nixos-anywhere)

**Executed:** 2026-10-20
**Host:** i7-7700K / GTX 3070 / 3.8 GB RAM / TEAM TM8FP6256G 238.5 GB NVMe
**Role:** second k3s node — an **agent/worker** joined to the `homelab-n150`
server (k8s node name `homelab`). See
[`PLAN.md`](../PLAN.md) §9–§13 for the full migration context.

The old occupant of the disk was an Alpine box (`homelab.local`,
192.168.1.194) that had previously been a Proxmox host. Its data was
confirmed disposable; the only irreplaceable bits (`.ssh`, service configs and
databases) were copied to `homelab-n150:/mnt/hdd/backup-temp/old-homelab-3070`
before anything was wiped.

---

## 0. Short version

```sh
# 1. build the target system on macair's linux-builder
nix build --no-link --print-out-paths .#nixosConfigurations.homelab-3070.config.system.build.toplevel

# 2. boot the nixos-anywhere kexec image from GRUB (see §2 — kexec is blocked here)
# 3. partition
nix run github:nix-community/nixos-anywhere -- --flake .#homelab-3070 \
  --target-host root@192.168.1.194 --build-on local --phases disko
# 4. make the installer's RAM store write to the target disk (see §3)
# 5. copy the closure over the LAN, then install
NIX_SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  nix copy --no-check-sigs --to ssh://root@<installer> /nix/store/<toplevel>
nix run github:nix-community/nixos-anywhere -- --flake .#homelab-3070 \
  --target-host root@<installer> --build-on local --phases install
# 6. fix the stale LVM signature on the swap partition (see §5), reboot
```

---

## 1. What the config does

| File | Purpose |
| --- | --- |
| `hosts/homelab-3070/disk-config.nix` | disko: 1 G ESP (`/boot`), 8 G swap, rest ext4 (`/`), GPT |
| `hosts/homelab-3070/hardware-configuration.nix` | **no** `fileSystems`/`swapDevices` (disko owns them), no `vars` |
| `hosts/homelab-3070/default.nix` | systemd-boot, sshd (key-only, root key), tailscale, sops secret `k3s-token`, k3s **agent** |
| `modules/nixos.nix` | `mkHost { host = "homelab-3070"; extraModules = [ inputs.disko.nixosModules.disko ]; }` |
| `output.nix` | `deploy.nodes.homelab-3070` → tailnet IP as root, `interactiveSudo = false` |
| `.sops.yaml` | own creation rule + the host's age key (from its real `/etc/ssh/ssh_host_ed25519_key`) |

Two rules that must survive future edits:

- **`--node-name=homelab-3070`** is explicit; the OS hostname is not used.
- **Never label this node `storage-tier=large`.** `local-large` PVs live on the
  N150's HDD; this node is `storage-tier=nvme`.
- The host's `--node-ip` / `--node-external-ip` are its **tailnet** IP
  (`100.83.20.73`), because flannel rides `tailscale0` (`--flannel-iface`).

---

## 2. Incident: `kexec` is blocked on this machine

`nixos-anywhere` boots a NixOS installer with `kexec`. It failed with:

```text
kexec_load failed: Operation not permitted
```

Root cause: the running kernel had `kernel.kexec_load_disabled = 1`, and that
sysctl is **one-way** (`echo 0 > /proc/sys/kernel/kexec_load_disabled` returns
`Invalid argument` — the kernel only accepts a transition *to* 1). It was still
`1` after a full reboot of the Alpine system, and no `/etc/sysctl.d` entry,
openrc service, initramfs script or kernel cmdline argument set it.

Workaround: boot the **same** kexec image from GRUB instead of via the syscall.
`nixos-anywhere` already downloads and unpacks it to `~/kexec/kexec/` on the
target, and its `run` script appends the target's root `authorized_keys` (and
the captured `ip`/route JSON) into the initrd — it only fails at the final
`kexec --load`. So, on the target:

```sh
mkdir -p /boot/nixos-installer
cp /root/kexec/kexec/bzImage /boot/nixos-installer/
cp /root/kexec/kexec/initrd  /boot/nixos-installer/     # already has the keys appended

cat >/etc/grub.d/40_custom <<'EOF'
#!/bin/sh
exec tail -n +3 $0
menuentry 'NixOS installer (nixos-anywhere)' --class gnu-linux {
	insmod part_gpt
	insmod ext2
	linux /boot/nixos-installer/bzImage init=/nix/store/dv2vmqbka57m5q5qb1cbq1vs29asvx9k-nixos-system-nixos-installer-kexec-25.11pre-git/init nouveau.modeset=0 console=tty0 console=ttyS0,115200 zswap.enabled=1 zswap.max_pool_percent=50 zswap.compressor=zstd zswap.zpool=zsmalloc root=fstab loglevel=4 lsm=landlock,yama,bpf
	initrd /boot/nixos-installer/initrd
}
EOF
chmod +x /etc/grub.d/40_custom
grep -q '^GRUB_DEFAULT=saved' /etc/default/grub || echo 'GRUB_DEFAULT=saved' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
grub-reboot 'NixOS installer (nixos-anywhere)'   # one-shot: a failure falls back to Alpine
reboot
```

The `init=` path and kernel params are copied verbatim from
`/root/kexec/kexec/run` (they point *inside* the initrd, so they are not
generic). The installer comes up as hostname `nixos-installer` on the same
DHCP lease with sshd on **port 22** (the old system used 2222).

From there, skip the `kexec` phase:

```sh
nix run github:nix-community/nixos-anywhere -- --flake .#homelab-3070 \
  --target-host root@192.168.1.194 --build-on local --phases disko
```

A NixOS **USB installer** works equally well (`--phases disko,install`).

---

## 3. Incident: the installer store is a 1.9 GB tmpfs

The kexec installer's `/` (and `/nix/store`) is a tmpfs sized at ~50 % of RAM
— 1.9 GB on a 3.8 GB box — with a squashfs lower layer. The target closure is
~4.7 GB, so `nix copy` into the installer store dies with `ENOSPC`/OOM (the
failure mode `PLAN.md` mentions).

Fix: stack an overlay on `/nix/store` whose **upper** lives on the freshly
created target filesystem, so store writes land on disk:

```sh
# on the installer, after the disko phase has mounted /mnt
mkdir -p /mnt/nix/.store-upper /mnt/nix/.store-work
mount -t overlay overlay \
  -o lowerdir=/nix/store,upperdir=/mnt/nix/.store-upper,workdir=/mnt/nix/.store-work \
  /nix/store
df -h /nix/store         # now shows the 225 G ext4 root
```

(`mount -o remount,upperdir=...` on the existing overlay is refused:
"overlay: No changes allowed in reconfigure".)

Then push the closure over the LAN instead of letting the target download it
from `cache.nixos.org` (~700 KB/s here):

```sh
# on macair
NIX_SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  nix copy --no-check-sigs --to ssh://root@192.168.1.194 /nix/store/<toplevel>
```

`--no-check-sigs` is needed because the linux-builder in this setup signs with
the **new** builder key, which the installer does not trust.

Finally:

```sh
nix run github:nix-community/nixos-anywhere -- --flake .#homelab-3070 \
  --target-host root@192.168.1.194 --build-on local --phases install
```

`nixos-install` then copies from the (disk-backed) installer store into
`/mnt/nix/store` and installs systemd-boot on the ESP. Clean up before the
reboot: `umount /nix/store; rm -rf /mnt/nix/.store-upper /mnt/nix/.store-work`.

---

## 4. Post-install: DHCP gave a new address

The box came back at **192.168.1.195** (not .194) — the NixOS dhcpcd client
presents a different client identifier. It was found with an ARP sweep from
`homelab-n150`:

```sh
for i in $(seq 1 254); do (ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 &); done; sleep 8
ip neigh | grep -i b8:85:84:ad:89:9d     # the NIC's MAC
```

The tailnet IP is what everything else uses, so the LAN address only matters
for rescue. (A DHCP reservation is still a good idea.)

---

## 5. Incident: leftover Proxmox LVM signature on the new swap partition

`systemctl --failed` showed:

```text
● dev-disk-by\x2dpartlabel-disk\x2dmain\x2dswap.swap   failed
● lvm-activate-pve.service                             failed
```

The disk had been a Proxmox host. disko's swap content only runs `mkswap`, and
`/dev/nvme0n1p2` still carried the old **LVM2 PV label** of a 237 GB `pve` VG
(`pvs` even reported `PSize 237.47g` for an 8 GB partition). LVM therefore
activated `pve-swap` as the swap device and left the intended unit failing —
and the inactive `pve/root` + `pve/data` LVs still describe extents that
overlap the new ext4 root, so any activation would be destructive.

Fix (on the installed system, before doing anything else):

```sh
swapoff -a
vgchange -an pve            # deactivate every LV of the stale VG
dmsetup remove pve-swap 2>/dev/null
wipefs -a /dev/nvme0n1p2    # erases the LVM2_member label at 0x218
mkswap -L disk-main-swap /dev/nvme0n1p2
systemctl reset-failed && swapon -a && systemctl --failed
```

Check with `blkid /dev/nvme0n1p2` → must say `TYPE="swap"`, not `LVM2_member`.
**Do this before installing sops/k3s** — a stray `lvm-activate` would corrupt
the root filesystem.

---

## 6. sops, tailnet, k3s agent

1. **Age key from the real host key** (do *not* precompute it — `--copy-host-keys`
   is not reliable across kexec):

   ```sh
   ssh root@192.168.1.195 'cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age
   # → age19naff7j89cny5dwufm4uppfkvac4p5vx3f8ejeyyeuf2nlcxdvaswz73s6
```text

   Add it to `.sops.yaml` under a **new** rule (`homelab\.yaml$` is anchored
   and does not match `homelab-3070.yaml`), then create the file with only the
   k3s join token:

   ```sh
   umask 077
   sops -d --extract '["k3s-token"]' secrets/homelab.yaml | sed 's/^/k3s-token: /' > /tmp/t.yaml
   sops encrypt --filename-override secrets/homelab-3070.yaml --output secrets/homelab-3070.yaml /tmp/t.yaml
   rm -f /tmp/t.yaml
   sops -d --extract '["k3s-token"]' secrets/homelab-3070.yaml | grep -q '^K10' && echo ok
   ```

2. **Tailscale** (interactive, like every other host):

   ```sh
   ssh root@192.168.1.195 'tailscale up --hostname=homelab-3070'   # approve the URL
   ssh root@192.168.1.195 'tailscale ip -4'                        # → 100.83.20.73
```

   Put that IP into `services.k3s.extraFlags` (`--node-ip`,
   `--node-external-ip`) and into `output.nix`. Disable key expiry for the node
   in the Tailscale admin console — it is an always-on server.

3. **Deploy:**

   ```sh
   git add -A
   nix run github:serokell/deploy-rs -- .#homelab-3070
   ```

   Notes on NixOS 26.11 + sops-nix: there is **no** `sops-install-secrets.service`
   unit anymore (that was pre-26.11). Secrets are exposed through systemd
   credentials: `/run/secrets` is a symlink to `/run/secrets.d/<generation>/`.
   Verify with `ls -l /run/secrets/k3s-token` (mode `0400 root`), not with
   `systemctl is-active sops-install-secrets`.

---

## 7. local-path storage

`local-path` (the `local-path-provisioner-standalone` Deployment) is
capacity-unaware and provisions on whichever node the pod runs. Its
`config.json` therefore needs an explicit entry for the new node, otherwise
pods scheduled here would get a `${VOL_DIR}` inside `/mnt/fast` (a path that
does not exist on this box):

```json
{
  "nodePathMap": [
    { "node": "homelab-3070", "paths": ["/var/lib/rancher/k3s/storage"] },
    { "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES", "paths": ["/mnt/fast"] }
  ]
}
```

`nodePathMap[].node` matches the **k8s node name**. The N150 stays covered by
`DEFAULT_PATH_FOR_NON_LISTED_NODES`; if it is ever added explicitly it must say
`homelab`, never `homelab-n150`.

Apply either by editing
`~/code/homelab-helm/services/local-path-storage/standalone.yml` (keep the
manifest as the source of truth) or, to avoid re-applying the whole file
(the repo's `kustomization.yml` is dirty), patch only the ConfigMap:

```sh
kubectl -n kube-system patch cm local-path-config --type=merge \
  -p "$(jq -Rn --arg c "$(cat /tmp/local-path-config.json)" '{data:{"config.json":$c}}')"
```

No restart: the provisioner re-reads it every 30 s. Verify with a 10 MiB PVC
pinned to the node — the PV path must be
`/var/lib/rancher/k3s/storage/pvc-<uid>_default_smoke-3070` and the
`local.path.provisioner/selected-node` annotation must be `homelab-3070`
(both confirmed). The PV is deleted (`reclaimPolicy: Delete` + `rm -rf`) when
the PVC is removed.

Negative check: a `storageClassName: local-large` PVC with a pod pinned to
`homelab-3070` must stay **Pending** — `local-large` only exists on the N150.

---

## 8. Verification performed

```sh
kubectl get nodes -o wide                  # homelab (control-plane,etcd) + homelab-3070 (agent)
kubectl get node homelab -o jsonpath='{.metadata.uid}'   # unchanged: 40bacc64-...
kubectl get node homelab-3070 --show-labels              # storage-tier=nvme, intel.../gpu=true
kubectl get pv -o json | jq -r '.items[] | select(.status.phase!="Bound") | .metadata.name'   # empty
kubectl get pvc -A --no-headers | awk '$3!="Bound"{print $1"/"$2}'   # same 5 pre-existing
kubectl get pods -A --no-headers | awk '$4!="Running" && $4!="Completed"'   # empty
kubectl get --raw '/readyz?verbose' | grep 'etcd ok'
kubectl -n default get endpoints prometheus-prometheus-node-exporter   # both node IPs
kubectl get ds -A            # every DESIRED == READY
```

Cross-node pod network over VXLAN-on-Tailscale (MTU 1230 inside pods,
1150-byte payloads, 0 % loss both directions):

```sh
kubectl run p3070 --image=busybox:1.37 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"homelab-3070"}}}' -- sleep 600
kubectl run pn150 --image=busybox:1.37 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"homelab"}}}' -- sleep 600
kubectl exec p3070 -- ping -c3 -s 1150 <pn150 podIP>
kubectl exec pn150 -- ping -c3 -s 1150 <p3070 podIP>
```

Also done while installing:

- `etcd-snapshot save` on the server before touching anything, and a copy of
  the old box's `.ssh` + service configs into
  `homelab-n150:/mnt/hdd/backup-temp/old-homelab-3070` (143 GB of media was
  left behind — the user confirmed it was disposable).
- `ssh-keygen -R homelab` / `-R homelab-n150` on macair after the SR-2 rename,
  then `ssh homelab-n150` re-accepted.
- The macair SMB mount was pinned to `//samba@…@100.89.132.36:30445/code-stash`
  *before* the rename and kept working (verified by remounting the same share).

---

## 9. Gotchas worth remembering

- `nixos-anywhere` uses port **2222** for the pre-install system and **22** for
  the installer (`--ssh-port` only affects the first hop).
- `--build-on local` needs macair's `linux-builder` VM. If it is down, builds
  fail with `platform mismatch` / `Failed to find a machine for remote build!`;
  a `sudo launchctl kickstart -k system/org.nixos.linux-builder` brings it back,
  but note the idle-stop watchdog can boot it out mid-build if it thinks the
  builder is idle. Recreate `/var/lib/linux-builder` if launchd refuses to start
  it (`exit 78`).
- On this box, `nix config show` as **root** shows compiled defaults — the
  NixOS settings live in `/etc/nix/nix.custom.conf` and are only visible in
  `nix config show` when run as a non-root user (the daemon serves them).
- The k3s node name of the N150 is still `homelab`. Any `nodeSelector`,
  `nodePathMap` or PV `nodeAffinity` must keep using `homelab` for that node.
