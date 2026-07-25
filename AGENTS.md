# AGENTS.md

Guide for AI agents working on this Nix configuration repository.

## Quick Start

This is a **dendritic Nix configuration** using **flake-parts**. All values flow through `config.*` — never use `specialArgs` or `extraSpecialArgs`.

```sh
# Validate configuration
nix flake check

# Apply changes on macair
sudo darwin-rebuild switch --flake .

# Deploy to remote hosts
nix run github:serokell/deploy-rs -- .#homelab
nix run github:serokell/deploy-rs -- .#hetzner-sg
```

**Important:** Always `git add` new/modified files before running `darwin-rebuild`. Nix flakes read from the Git index, not the working tree.

## Architecture

```
.
├── flake.nix              # Entry point — imports modules, programs, output
├── output.nix             # deploy-rs configuration only
├── modules/               # Feature modules (flake-parts)
│   ├── identity.nix       # User identity options + deferredModule for HM/nixos
│   ├── darwin.nix         # nix-darwin config (reads from flake-parts options)
│   ├── nixos.nix          # NixOS configs (reads from flake-parts options)
│   └── default.nix        # Imports all modules
├── programs/              # Program modules (auto-discovered, each exports flake.homeModules.<name>)
│   ├── default.nix        # Auto-discovers all program directories
│   ├── git/               # Git tool config (delta, pager, merge style, lfs)
│   ├── shell/             # Zsh + conditional aliases/session vars
│   ├── skills/            # Agent skills (has own flake.nix, consumed as input)
│   └── … (17 active program dirs)
├── hosts/                 # Host configurations
│   ├── macair/default.nix               # Darwin config
│   ├── homelab/default.nix              # NixOS config (k3s, podman, wireguard)
│   └── hetzner/default.nix              # NixOS config (k3s server, wireguard)
├── users/napatsc/         # HM core (packages, SMB mount, sops)
└── secrets/               # SOPS-nix secrets
```

## Key Concepts

### Dendritic Pattern

Values share through **let bindings** and **flake-parts options**, never through `specialArgs` or `extraSpecialArgs`.

- User identity → `modules/identity.nix` defines `options.user.*`
- Lower-level modules use `deferredModule` type
- Configurations read from `config.*`

### flake-parts Modules

Every file is a flake-parts module. Programs export `flake.homeModules.<name>` which are automatically merged by flake-parts.

### Auto-Discovery

`programs/default.nix` automatically discovers all program directories. To add a new program:

1. Create `programs/<name>/default.nix`
2. Export `flake.homeModules.<name>` (see existing programs for structure)
3. Done — auto-discovery picks it up

Exception: `programs/skills/` has its own `flake.nix` and is consumed as a flake input, not a direct import.

## Adding a New Program

Create `programs/myprogram/default.nix`:

```nix
{ ... }: {
  flake.homeModules.myprogram = { pkgs, ... }: {
    # Home Manager options here
    programs.myprogram = {
      enable = true;
      # ...
    };
  };
}
```

Then `git add` and test with `nix flake check` + `darwin-rebuild switch --flake .`.

## Hosts

| Host | Type | Description |
|------|------|-------------|
| macair | Darwin | macOS laptop — 17 programs (desktop + dev + k8s) |
| homelab | NixOS | Home server — k3s, podman, wireguard |
| hetzner-sg | NixOS | Cloud server — k3s, wireguard |

## Common Tasks

### Disable a program

Comment it out in `programs/default.nix` (or remove the directory). The auto-discovery won't pick it up.

### Update a program

Edit `programs/<name>/default.nix`. Run `darwin-rebuild switch --flake .` to apply.

### Add host-specific config

Edit `hosts/<name>/default.nix`. Host configs read from `config.*` (dendritic pattern).

### Debug issues

```sh
# Check for syntax/evaluation errors
nix flake check

# See what the flake produces
nix flake show

# Build a specific output (dry run)
nix build .#darwinConfigurations.macair.system
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Path '...' does not exist in Git repository` | File not `git add`ed | `git add <path>` |
| `option ... was accessed but has no value defined` | Module accesses unset config | Check option deps, provide default |
| `option defined multiple times` | Same undeclared flake output | Use declared option (like `flake.homeModules`) |
| `attribute 'pkgs' missing` | `pkgs` outside `perSystem` | Keep `pkgs`-dependent logic inside HM module args |

## File Conventions

- **Programs**: Each directory has `default.nix` exporting `flake.homeModules.<name>`
- **Modules**: Each file is a flake-parts module in `modules/`
- **Hosts**: Each host has `hosts/<name>/default.nix`
- **Secrets**: SOPS-nix in `secrets/`, referenced via `../../secrets` in host configs

## Tips

- `nix flake check` validates Nix expressions but doesn't build or activate
- Always test with `darwin-rebuild switch --flake .` on the actual machine
- The skills directory (`programs/skills/`) is special — it's a flake input, not a regular program
- `sketchybar` is deactivated but kept in `programs/sketchybar/` — uncomment to reactivate
