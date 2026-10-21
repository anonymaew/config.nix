# homelab-3070 — disko layout (destructive; only used by nixos-anywhere)
#
# disko emits plain `fileSystems`/`swapDevices` definitions, so
# hardware-configuration.nix must NOT declare them (no --generate-hardware-config).
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
