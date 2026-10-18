# `config.nix`

My computer/server configuration on Nix language.

```
# nix flake show
├───darwinConfigurations: unknown
├───deploy: unknown
└───nixosConfigurations
    ├───hetzner-sg: NixOS configuration
    ├───homelab: NixOS configuration
    └───linode-us: NixOS configuration
```

## Deployment

For Mac machine:

```sh
sudo darwin-rebuild switch --flake .
```

For deploying flakes to remote machine:

```sh
# for homelab
nix run github:serokell/deploy-rs -- .#homelab
# for hetzner-sg
nix run github:serokell/deploy-rs -- .#hetzner-sg
# for linode-us (Linode VPS)
nix run github:serokell/deploy-rs -- .#linode-us
```

## Install on darwin from scratch

1. install determinate-nix
2. change hostname
3. install xcode (getting git)
4. first `darwin-rebuild switch`

   <details>
   <summary>Linux builder: upstream `linux-builder-vz` (no bootstrap builder needed)</summary>

   [`darwin.linux-builder-vz`](https://github.com/NixOS/nixpkgs/blob/master/doc/packages/darwin-builder.section.md) (nixpkgs [PR #544193](https://github.com/NixOS/nixpkgs/pull/544193), Hydra-cached)
   runs the NixOS builder guest on Apple's Virtualization.framework via
   [pkgs.vzvm](https://github.com/applicative-systems/vzvm): `aarch64-linux` natively,
   `x86_64-linux` via Rosetta (with a working `/dev/kvm` via nested virtualization, so
   `nixos-test` still works). Since it's cached, a fresh install needs no intermediate
   builder — the old cpick/nix-rosetta-builder bootstrap dance is gone.

   **Prereq**: Rosetta 2 — check with `/usr/bin/arch -x86_64 /usr/bin/true` or install
   with `softwareupdate --install-rosetta`. (macOS 27 includes Linux-VM Intel translation
   natively, so on 27 the check always passes.)

   Enablement in `hosts/macair/default.nix` — Determinate's module wires up the launchd
   daemon, the `ssh_config.d` alias and the `/etc/nix/machines` entry itself (nix-darwin's
   own `nix.linux-builder` would require `nix.enable = true`):

   ```nix
   determinateNix = {
     enable = true;
     distributedBuilds = true;
     nixosVmBasedLinuxBuilder = {
       enable = true;
       hostName = "linux-builder";           # ssh alias + machines hostname
       package = pkgs.darwin.linux-builder-vz;
       systems = [ "aarch64-linux" "x86_64-linux" ];
       maxJobs = 8;
       speedFactor = 1;
       supportedFeatures = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
     };
   };
   ```

   Then `git add` everything and switch:

   ```sh
   sudo darwin-rebuild switch --flake .
   ```

   Verify both platforms route to `ssh-ng://builder@linux-builder`:

   ```sh
   nix build --impure --expr 'with builtins.getFlake "nixpkgs";
     legacyPackages.x86_64-linux.runCommand "probe" { } "uname -m > \"$out\""' && cat result
   # expect: x86_64   (also verify `aarch64-linux` -> aarch64)
   ```

   **VMs are on-demand** in the sense that the daemon keeps the VM running
   (`KeepAlive`); unlike the old rosetta-builder there is no idle power-off, so the
   builder holds RAM while the Mac is on.

   **Migrating from cpick/nix-rosetta-builder**: remove the flake input, the module
   import in `modules/darwin.nix` and the old `nix-rosetta-builder` block, then switch
   (the old launchd daemon plist is removed by the switch). Leftover state to clean up:

   ```sh
   sudo rm -rf /var/lib/rosetta-builder
   # service account created by the old module:
   sudo dscl . -delete /Users/_nixrosettabuilder   # if present
   sudo dscl . -delete /Groups/nixrosettabuilder   # if present
   ```

   </details>
5. uninstall xcode

## Migration checklist

- **Important**: secret keys
  - [ ] sops keys in `~/.config/sops`
  - [ ] GPG keys (export as ascii and reimport)
  - [ ] SSH key `~/.ssh/`
  - [ ] kube config `~/.kube`
- **Data**
  - [ ] Zen history/sessions/cookies
  - [ ] pi-coding-agent sessions at `~/.pi/agent/sessions`
  - [ ] tmux (resurrect) sessions at `~/.local/share/tmux/resurrect/last`
