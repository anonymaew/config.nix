# Installing NixOS on a Linode from Ubuntu (in place)

This document records how `linode-us` (Linode `45.33.39.244`) was converted from a
stock Ubuntu image to NixOS **in place** — no rescue console, no re-provisioning —
and then wired into this repository's flake. It is a field guide: the exact
commands, the traps hit, and why each workaround exists.

## The problem

A fresh Linode Ubuntu image has an unusual disk layout:

- **Partitionless disk**: the whole `/dev/sda` is one big `ext4` filesystem — no
  partition table at all (verify with `fdisk -l /dev/sda`; `lsblk` shows `sda`
  directly holding `/`, and the MBR is all zeros).
- **The hypervisor boots the guest**: Linode's "GRUB 2" boot mode reads
  `/boot/grub/grub.cfg` from the root filesystem and loads the kernel+initrd
  itself. The guest's MBR is never executed. Evidence: `/proc/cmdline` shows
  `BOOT_IMAGE=/boot/vmlinuz-...` and `dd if=/dev/sda bs=512 count=1` is zeros.
- `net.ifnames=0` is already injected at boot (that's why the interface is `eth0`).
- `/dev/sdb` is a small swap partition.

Implication for NixOS: a normal `boot.loader.grub.device = "/dev/sda"` **fails** —
GRUB cannot embed its core image into a partitionless ext4 (and refuses blocklists).
The correct setting is `boot.loader.grub.device = "nodev"`: NixOS still generates
`/boot/grub/grub.cfg` (which Linode's glue boot reads) without touching any device.

## Strategy

1. Install `nix` on the running Ubuntu (multi-user, with the official installer).
2. Generate + review `/etc/nixos` configs first (`NO_INFECT=1` dry run).
3. Convert in place with `nixos-infect` but hold the reboot (`NO_REBOOT=1`).
4. Patch the GRUB problem (`nodev`), rebuild, re-stage, then reboot and verify.
5. Replace the throwaway config with the flake-managed host (`hosts/linode-us/`).

> Use the **`elitak/nixos-infect`** fork. The old canonical
> `nix-community/nixos-infect` URL 404s (repo vanished); `elitak` is upstream.
> The script is **bash-only** (it uses `<<<` herestrings in `makeConf`) — never
> run it with `sh`.

## Steps

### 0. Preflight

```sh
ssh -o BatchMode=yes -o ConnectTimeout=10 root@45.33.39.244 '
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
  fdisk -l /dev/sda
  df -h /
  ls -la /root /home        # confirm nothing valuable is on the box
  cat /proc/cmdline         # BOOT_IMAGE=... net.ifnames=0  -> hypervisor boots via grub.cfg
  dd if=/dev/sda bs=512 count=1 2>/dev/null | xxd | head -2   # expect all zeros (no MBR)
'
```

Only proceed if the box is disposable (fresh VPS). The conversion wipes `/etc`
of the old OS on first boot (NixOS "lustrate").

### 1. Install nix (multi-user) on Ubuntu

```sh
curl -fsSL https://nixos.org/nix/install -o /tmp/nix-install.sh
sh /tmp/nix-install.sh --daemon
```

**Trap (nixbld GID).** The installer hard-fails with weird messages if the
`nixbld` group exists with a small GID (a stray `groupadd nixbld` creates GID
1000 → "unable to install …" / "has no members" / "can't handle UID 1000 →
export NIX_BUILD_GROUP_ID"). Fix from a clean state: `groupdel nixbld`, then run
the installer again so it creates the group itself (`gid 30000` + `nixbld1..32`).

### 2. Stage the configs (no-op dry run)

```sh
scp nixos-infect root@45.33.39.244:/root/
ssh root@45.33.39.244 'bash -n /root/nixos-infect && echo OK'
setsid nohup env NO_INFECT=1 NO_REBOOT=1 bash /root/nixos-infect \
  > /root/infect-stage.log 2>&1 < /dev/null &
```

With `NO_INFECT=1` the script only does its environment fixups (apt installing
`bzip2`/`xz-utils`/… if missing) and writes `/etc/nixos/configuration.nix` +
`/etc/nixos/hardware-configuration.nix`. Review both before anything destructive.

The generated `hardware-configuration.nix` should show:
`boot.loader.grub.device = "/dev/sda"`, `fileSystems."/" = { device = "/dev/sda"; fsType = "ext4"; }`,
`swapDevices = [ { device = "/dev/sdb"; } ]` and the `qemu-guest.nix` profile import.

### 3. Patch the generated config for this environment

`/etc/nixos/configuration.nix` (as generated) then gets:

```nix
networking.hostName = "linode";
networking.usePredictableInterfaceNames = false;   # keep eth0 (matches Linode's net.ifnames=0)
networking.interfaces.eth0.useDHCP = true;         # Linode DHCP hands back the same IP by MAC
boot.kernelParams = [ "console=tty0" "console=ttyS0,19200n8" ];  # Lish/Glish serial
services.openssh.settings.PasswordAuthentication = false;
```

The script fills in the authorized key automatically from
`/root/.ssh/authorized_keys`, and keeps the SSH host keys across the switch
via `/etc/NIXOS_LUSTRATE`.

### 4. Convert (with the reboot held)

```sh
setsid nohup env NO_REBOOT=1 bash /root/nixos-infect > /root/infect.log 2>&1 < /dev/null &
tail -f /root/infect.log
```

This re-runs the nix installer (fine now), swaps in the `nixos-25.11` channel,
builds `nix-env --set … -A system` into `/nix/var/nix/profiles/system`, and
runs `switch-to-configuration boot`.

**Trap (GRUB embedding).** The log ends with:

```
grub-install: error: will not proceed with blocklists.
install-grub.pl: installation of GRUB on /dev/sda failed
```

Expected on partitionless ext4 — and unnecessary, since Linode never executes
the guest MBR. Fix:

```sh
sed -i 's|boot.loader.grub.device = "/dev/sda";|boot.loader.grub.device = "nodev";|' /etc/nixos/hardware-configuration.nix
. /root/.nix-profile/etc/profile.d/nix.sh
export NIXOS_CONFIG=/etc/nixos/configuration.nix          # required — the module looks up <nixos-config>
nix-env --set -I nixpkgs="$(realpath /root/.nix-defexpr/channels/nixos)" \
  -f '<nixpkgs/nixos>' -A system -p /nix/var/nix/profiles/system
/nix/var/nix/profiles/system/bin/switch-to-configuration boot   # now exits 0
```

`nodev` makes `install-grub.pl` skip the device write and just regenerate
`/boot/grub/grub.cfg`. (The first `sed` alone does nothing — the bootloader
config is compiled into a store path; you must rebuild.)

Verify the staged boot before rebooting:

```sh
cat /boot/grub/grub.cfg     # menuentry "NixOS" → linux (drive2)/nix/store/…-linux…/bzImage …
ls -la /nix/var/nix/profiles/system/{kernel,initrd}
ls /nix/store/<kernel-path>/bzImage  /nix/store/<initrd-path>/initrd
```

All paths referenced by `grub.cfg` must exist in `/nix/store`.

### 5. Reboot + verify

```sh
ssh root@45.33.39.244 'nohup bash -c "sleep 2; systemctl reboot" >/dev/null 2>&1 &'
# … poll every ~7s until ssh answers again (~90-120s) …
ssh root@45.33.39.244 '
  cat /etc/os-release | grep -E "BUILD_ID|HOME_URL"   # NixOS 25.11
  hostname                                          # linode
  ip -brief addr                                    # eth0 → 45.33.39.244/24 (DHCP restored)
  ip route
  systemctl is-active sshd
  systemctl --failed
  /run/current-system/sw/bin/iptables-nft -S INPUT | head   # firewall still on
'
```

The `nft` CLI isn't in a minimal closure; `iptables-nft` reads the same
nftables ruleset. Expect the `nixos-fw` chain with ACCEPT for
loopback/established/22/ICMP and DROP for the rest (a closed port should
time out, not "connection refused").

You should also keep the authorized key where other tools expect it
(`deploy-rs`/`scp` don't read sshd's `authorized_keys.d`):

```sh
cp /etc/ssh/authorized_keys.d/root /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
```

### 6. Adopt into the flake

Replace the throwaway config with a managed host (see `hosts/linode-us/`):

- `hosts/linode-us/hardware-configuration.nix` — the live file (grub `nodev`,
  `/dev/sda` root, `/dev/sdb` swap, `qemu-guest.nix`).
- `hosts/linode-us/default.nix` — hostname, DHCP/eth0, serial console, user
  `napatsc` + hardened SSH (mirrors `hetzner-sg`); `system.stateVersion = "26.11"`
  (fresh host at the current release — bumping is correct only on a new install).
- `modules/nixos.nix` — add the `nixosConfigurations.linode-us` entry.
- `output.nix` — add the `deploy.nodes.linode-us` entry (`hostname = "45.33.39.244"`).

Then (flakes read the **git index**, not the working tree):

```sh
git add hosts/linode-us modules/nixos.nix output.nix docs/install-nixos-on-linode.md
nix eval .#nixosConfigurations.linode-us.config.system.build.toplevel.drvPath   # config validates
nix run github:serokell/deploy-rs -- .#linode-us
```

> **Deploy user is root.** `deploy-rs` connects as `sshUser = "root"` (not
> `napatsc`) for `linode-us`: napatsc has no password/sudo setup, so a
> non-interactive deploy can't su to root — while root's key auth is declared
> directly in `hosts/linode-us/default.nix` (and doubles as the rescue path).
> If you later configure sudo for napatsc, switch `sshUser` back to `"napatsc"`.
> `services.openssh.restartIfChanged = false` keeps sshd from restarting
> mid-activation, which would otherwise kill deploy-rs's own control
> connection and report a bogus deploy failure.

## Gotchas summary

| Trap | Symptom | Fix |
| --- | --- | --- |
| `nixbld` GID pre-created | installer dies on group id/members | `groupdel nixbld`, rerun installer |
| `sh nixos-infect` | `Syntax error: redirection unexpected` (line 68) | run with `bash` |
| GRUB on `/dev/sda` | `will not proceed with blocklists` | `grub.device = "nodev"` + rebuild (`NIXOS_CONFIG` env) |
| editing /etc/nixos without rebuild | nothing changes in staged boot | rebuild with `nix-env --set … -A system` |
| predictable NIC names | DHCP'd name isn't `eth0` on first boot | `usePredictableInterfaceNames = false` |
| lost shell access | 🔒 | Linode Lish (serial `ttyS0`, 19200 baud) still works because of `boot.kernelParams` — keep it |
| old `/etc` SSH state | … | `NIXOS_LUSTRATE` preserves `etc/ssh/ssh_host_*` + `/etc/nixos` |

## Why two-phase (`NO_INFECT=1` then real run)

`makeConf` skips regenerating the configs if `/etc/nixos/configuration.nix`
already exists. Running once with `NO_INFECT=1` generates them for review;
running with the config already in place applies your patched files. (The
second `nix` install inside `infect()` is idempotent — groups/users already
exist.)

## Runbook references

- Original script: `https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect`
- Linode boot modes: read `/boot/grub/grub.cfg` (GRUB 2 mode) — never the MBR
- Check the box after any deploy: `systemctl --failed`, `uptime`, `df -h /`,
  `iptables-nft -S INPUT`
