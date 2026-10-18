# `config.nix`

Declarative Nix, nix-darwin and NixOS configuration for my machines — a
**dendritic flake** built on **flake-parts**.

## Hosts

| Host | System | Role |
| --- | --- | --- |
| `macair` | `aarch64-darwin` | macOS laptop — desktop + dev + k8s tooling |
| `homelab` | `x86_64-linux` | home server — k3s single-node server, podman, tailscale |
| `linode-us` | `x86_64-linux` | public VPS — nftables DNAT ingress proxy to homelab traefik over tailscale |

## Architecture

The repository follows the **dendritic pattern**: there is no central
`configuration.nix` that wires everything together. Instead **every `.nix` file
is a flake-parts module** that publishes options and reads them back through
`config.*`. Within the flake, shared values travel through `config.*`; the
resolved identity is injected into NixOS / Home Manager with `specialArgs` only
at the configuration boundary.

```text
.
├── flake.nix              # entry point — inputs + flake-parts.mkFlake
│                          #   imports home-manager.flakeModules.home-manager,
│                          #   ./modules, ./output.nix, ./programs
├── output.nix             # flake outputs that aren't configs — deploy-rs nodes
├── modules/               # feature modules (each is a flake-parts module)
│   ├── default.nix        # imports identity.nix, nixos-base.nix,
│   │                      #   darwin.nix, nixos.nix
│   ├── identity.nix       # single source of truth for config.user.*
│   ├── nixos-base.nix     # shared NixOS settings → config.nixos.modules.base
│   ├── darwin.nix         # builds flake.darwinConfigurations.macair
│   └── nixos.nix          # builds flake.nixosConfigurations.{homelab,linode-us}
├── programs/              # Home Manager modules, auto-discovered
│   ├── default.nix        # discovers programs/*/default.nix
│   ├── git/default.nix    # each exports flake.homeModules.<name>
│   ├── shell/default.nix
│   └── …                  # (git, shell, neovim, tmux, direnv, starship, …)
├── hosts/                 # per-host config + hardware
│   ├── macair/
│   │   ├── default.nix    # hostname, nix/determinate, launchd, PAM, keyboard
│   │   ├── mac.nix        # macOS System Settings via nix-plist-manager (user scope)
│   │   └── snapshots/     # dock / menu bar / wallpaper plists
│   ├── homelab/           # NixOS — k3s single-node server, podman, tailscale
│   └── linode-us/         # NixOS — nftables DNAT ingress proxy
├── users/                 # Home Manager core for the primary user
│   └── napatsc/default.nix
├── secrets/               # SOPS-encrypted secrets (age recipients in .sops.yaml)
└── docs/                  # field guides and migration records
```

### How the pieces fit

- **`flake.nix`** evaluates everything with
  `flake-parts.lib.mkFlake`, pulls in `./modules`, `./output.nix` and
  `./programs`, and declares the supported `systems`
  (`aarch64-darwin`, `x86_64-linux`).

- **Identity** lives in exactly one place: `modules/identity.nix` declares
  `options.user` (`username`, `fullName`, `email`, `pgpKey`, `sshKey`). Every
  other layer consumes `config.user` instead of repeating the values.

- **Programs are auto-discovered.** Each program directory holds a
  `default.nix` exporting `flake.homeModules.<name>`. `programs/default.nix`
  uses `builtins.readDir` to find every directory that has a `default.nix`
  (skipping `skills`, which is consumed as a flake input) and imports it. The
  darwin configuration (`modules/darwin.nix`) pulls all of `self.homeModules`
  into the macair home-manager user, so a new program needs **no edit anywhere
  else**.

- **Shared NixOS boilerplate** lives in `modules/nixos-base.nix` and is exposed
  as the flake-parts option `config.nixos.modules.base` — nix settings,
  automatic garbage collection / store optimisation, locale, and the common
  server packages. Both `homelab` and `linode-us` include it, so the two
  servers stay consistent without copy-paste.

- **macOS System Settings** are declared in `hosts/macair/mac.nix` through
  [nix-plist-manager](https://github.com/SushyDev/nix-plist-manager) at **user
  (home-manager) scope**. `system.defaults` was removed on purpose so there is a
  single writer per plist. See [`docs/macos-plist.md`](docs/macos-plist.md) for
  the option map, snapshot workflow and rollback.

- **Hosts** are assembled in the `modules/` layer: `modules/darwin.nix` builds
  `flake.darwinConfigurations.macair`, and `modules/nixos.nix` builds
  `flake.nixosConfigurations.homelab` and `.linode-us`. The `deploy.nodes` for
  the remote hosts are declared in `output.nix`.

## Adding a program

1. Create `programs/myprogram/default.nix` exporting
   `flake.homeModules.myprogram`:

   ```nix
   { ... }: {
     flake.homeModules.myprogram =
       { pkgs, ... }: {
         # Home Manager options here
         programs.myprogram = {
           enable = true;
           # ...
         };
       };
   }
   ```

2. `git add programs/myprogram/default.nix`

That's it — `programs/default.nix` discovers it and the darwin configuration
imports the module automatically. Validate with `nix flake check` and apply with
`sudo darwin-rebuild switch --flake .`.

> `programs/skills/` is the exception: it has its own `flake.nix` and is
> consumed as the `agent-skills` flake input, not imported directly.

## Adding a host

1. Create the host directory, e.g. `hosts/myhost/default.nix` (plus
   `hardware-configuration.nix` for a NixOS host).
2. Register the configuration in the matching `modules/` file:
   - NixOS → add a `config.flake.nixosConfigurations.myhost` entry in
     `modules/nixos.nix`, importing the host directory, the sops-nix module,
     `config.nixos.modules.identity` and — for a server — `config.nixos.modules.base`.
   - Darwin → add a `config.flake.darwinConfigurations.myhost` entry in
     `modules/darwin.nix`.
3. For a remote host, add a `flake.deploy.nodes.myhost` entry in `output.nix`
   (hostname, `sshUser`, `user`, and the `deploy-rs` activation path).
4. `git add` the new/changed files, run `nix flake check`, then deploy.

## Deployment

Always `git add` new or modified files first — Nix flakes read from the Git
index, not the working tree.

On macair (apply locally):

```sh
sudo darwin-rebuild switch --flake .
```

Deploy to the remote hosts with deploy-rs:

```sh
nix run github:serokell/deploy-rs -- .#homelab
nix run github:serokell/deploy-rs -- .#linode-us
```

Validate the tree without building or activating anything:

```sh
nix flake check
```

## Install on darwin from scratch

1. install determinate-nix
2. change hostname
3. install xcode (getting git)
4. first `darwin-rebuild switch`

   <details>
   <summary>Linux builder: upstream <code>linux-builder-vz</code> (no bootstrap builder needed)</summary>

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

   **VMs are on-demand**: the repo adds an `org.nixos.linux-builder-idle-stop`
   launchd timer that bootouts the builder daemon after 15 minutes without a
   connection, and an ssh `ProxyCommand` that re-bootstraps it on the next build
   (the first build after idle pays a ~30–60s cold boot).

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

## Docs

- [`AGENTS.md`](AGENTS.md) — working notes for AI agents on this repo
- [`docs/macos-plist.md`](docs/macos-plist.md) — macOS System Settings → nix-plist-manager migration
- [`docs/install-nixos-on-linode.md`](docs/install-nixos-on-linode.md) — in-place NixOS install on the Linode VPS
- [`docs/control-plane-migration.md`](docs/control-plane-migration.md) — k3s control-plane move (hetzner → homelab)
