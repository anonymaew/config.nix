# `config.nix`

My computer/server configuration on Nix language.

```
# nix flake show
├───darwinConfigurations: unknown
├───deploy: unknown
└───nixosConfigurations
    ├───hetzner-sg: NixOS configuration
    └───homelab: NixOS configuration
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
```

## Install on darwin from scratch

1. install determinate-nix
2. change hostname
3. install xcode (getting git)
4. disable nix-rosetta, and do darwin-switch as from nix run ...
5. bootstrap nix-rosetta within determinate-nix

   <details>
   <summary>Bootstrap sequence (5.1–5.6): nix-rosetta-builder alongside Determinate Nix</summary>

   [nix-rosetta-builder](https://github.com/cpick/nix-rosetta-builder) runs a
   Lima VM that builds `aarch64-linux` natively and `x86_64-linux` via Rosetta 2.
   Its VM image is in **no binary cache**, so it must be built by an existing
   Linux builder first.

   **Prereq**: Rosetta 2 — check with `/usr/bin/arch -x86_64 /usr/bin/true`
   or install with `softwareupdate --install-rosetta`.

   5.1. **Phase A — temporary bootstrap builder**

   The hydra-cached nixpkgs `darwin.linux-builder` (QEMU-based) needs no Linux
   builder of its own to install. Import the module in `modules/darwin.nix`:

   ```nix
   inputs.nix-rosetta-builder.darwinModules.default
   { nix-rosetta-builder.onDemand = true; }
   ```

   and in `hosts/macair/default.nix`:

   ```nix
   determinateNix = {
     enable = true;
     distributedBuilds = true;                 # use /etc/nix/machines
     nixosVmBasedLinuxBuilder.enable = true;   # TEMPORARY
   };
   # rosetta VM not yet usable: its image isn't built
   nix-rosetta-builder.enable = false;

   # M5/macOS 26 ONLY: the linux-builder image hard-codes `-machine
   # virt,gic-version=2,accel=hvf`, but Hypervisor.framework rejects GICv2.
   # run-nixos-vm forwards $QEMU_OPTS last, so gic-version=3 overrides it:
   launchd.daemons.nixos-vm-based-linux-builder.environment.QEMU_OPTS =
     "-machine virt,gic-version=3";
   ```

   Then `git add` everything and switch:

   ```sh
   sudo darwin-rebuild switch --flake .   # downloads ~400 MiB
   ```

   5.2. **Verify the bootstrap builder** — a derivation that *must* build
   (nothing like it exists in any cache):

   ```sh
   nix build --impure --expr 'with builtins.getFlake "nixpkgs";
     legacyPackages.aarch64-linux.runCommand "probe" { }
       "uname -a > \"$out\""' && cat result
   # expect: Linux ... aarch64 GNU/Linux
   ```

   5.3. **Phase B — enable the rosetta builder**

   Flip `nix-rosetta-builder.enable = true` and register the VM as a build
   machine in `hosts/macair/default.nix`. It must go in
   `determinateNix.buildMachines` — the module's own `nix.buildMachines` is only
   rendered when `nix.enable = true`, and Determinate manages Nix here, so that
   setting is inert:

   ```nix
   nix-rosetta-builder = { enable = true; onDemand = true; };

   determinateNix.buildMachines = [
     {
       hostName = "rosetta-builder";
       sshUser = "builder";
       sshKey = "/var/lib/rosetta-builder/ssh_user_ed25519_key";
       protocol = "ssh-ng";
       systems = [ "aarch64-linux" "x86_64-linux" ];
       maxJobs = 8;
       speedFactor = 1;
       supportedFeatures = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
       mandatoryFeatures = [ ];
     }
   ];
   ```

   Keep the bootstrap builder enabled. Switch again — the rosetta VM image
   (NixOS + kernel) builds on the bootstrap VM and the lima fork from source;
   this switch takes a while (up to ~1 h on M5):

   ```sh
   sudo darwin-rebuild switch --flake .
   ```

   5.4. **Verify the rosetta builder** — both platforms must route to
   `ssh-ng://builder@rosetta-builder` (the on-demand VM boots on first
   connection):

   ```sh
   nix build --impure --expr 'with builtins.getFlake "nixpkgs";
     legacyPackages.x86_64-linux.runCommand "probe" { } "uname -m > \"$out\""' && cat result
   # expect: x86_64   (also verify `aarch64-linux` -> aarch64)
   ```

   With `onDemand = true` the VM powers itself off after 180 min idle; a Linux
   build boots it in a few seconds (first build is slower).

   5.5. **Phase C — drop the bootstrap builder**

   Remove `nixosVmBasedLinuxBuilder.enable` (and the QEMU_OPTS workaround) from
   `hosts/macair/default.nix`, then switch. `/etc/nix/machines` now lists only
   `rosetta-builder`.

   5.6. **Cleanup** — the bootstrap VM leaves a ~10 GB disk behind:

   ```sh
   sudo rm -rf /var/lib/nixos-vm-based-linux-builder
   ```

   </details>
6. uninstall xcode

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
