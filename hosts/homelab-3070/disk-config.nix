# homelab-3070 — disko layout (destructive; only used by nixos-anywhere)
#
# disko emits plain `fileSystems`/`swapDevices` definitions, so
# hardware-configuration.nix must NOT declare them (no --generate-hardware-config).
#
# NOTE: this disk used to be a Proxmox host. disko only runs `mkswap` on the swap
# partition, so an old LVM2 PV label survived and LVM grabbed the partition (the
# systemd swap unit failed and stale `pve/*` LVs still described extents over the
# new root). If the same signature shows up again:
#   swapoff -a; vgchange -an <vg>; wipefs -a /dev/disk/by-partlabel/disk-main-swap
#   mkswap -L disk-main-swap /dev/disk/by-partlabel/disk-main-swap; swapon -a
# See docs/install-nixos-on-homelab-3070.md §5.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1"; # TEAM TM8FP6256G 238.5G — verify with lsblk before install
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
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
        };
        swap = {
          size = "8G";
          content = { type = "swap"; }; # no resumeDevice / hibernation
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
