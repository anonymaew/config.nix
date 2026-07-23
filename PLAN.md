# Nix Configuration Refactoring Plan

## Handoff Summary

**Date:** 2026-07-23
**User:** napatsc
**Workspace:** `/Users/napatsc/code/nix`
**Goal:** Refactor Nix configuration to follow the dendritic pattern using flake-parts

---

## Current State

### Phase 1–3 Complete ✅

**Completed by:** Agent on 2026-07-23
**Status:** `nix flake check` passes ✅, `darwin-rebuild switch --flake .` works on macair ✅

### Current Structure

```
.
├── flake.nix              # flake-parts entry point + HM flake-parts module
├── output.nix             # flake-parts module — darwin/nixos/deploy configs
├── default.nix            # Darwin base config (users, brew-nix, nix settings)
├── system.nix             # macOS system defaults
├── home.nix               # Home Manager — packages, shell, env vars, SMB mount
├── programs/
│   ├── default.nix        # Imports index — each program is its own flake-parts module
│   ├── sketchybar/        # Deactivated (commented out in index)
│   ├── skills/            # Own flake.nix — consumed as agent-skills input
│   └── … (13 active program dirs, each exporting flake.homeModules.<name>)
├── hosts/                 # Placeholders for host configs (Phase 4)
│   ├── macair/
│   ├── homelab/
│   └── hetzner/
├── users/napatsc/         # User-specific Home Manager config
├── homelab/               # NixOS config (active)
├── hetzner/               # NixOS config (active)
├── modules/               # Shared NixOS/darwin modules
├── overlays/              # Nixpkgs overlays
└── secrets/               # SOPS-nix secrets
```

### Key Milestones

| Phase | Status | Summary |
|-------|--------|---------|
| Phase 1 | ✅ | flake-parts foundation, `output.nix` conversion |
| Phase 2 | ✅ | All 14 programs export via `flake.homeModules.*` |
| Phase 3 | ✅ | Desktop programs converted to HM modules, `setups/` removed, dendritic refactor |
| Phase 4 | ⏳ | Host configs (macair, homelab, hetzner) |
| Phase 5 | ⏳ | Migrate user config to `users/napatsc/` |
| Phase 6 | ⏳ | Cleanup old files, README, testing |

---

## What Changed in Phase 3

| File/Dir | Change |
|---|---|
| `flake.nix` | Added `home-manager.flakeModules.home-manager` — declares `flake.homeModules` as mergeable option |
| `programs/*/default.nix` | Each program now exports `flake.homeModules.<name>` (is its own flake-parts module) |
| `programs/default.nix` | Converted from `flake.homeManagerModules` aggregation → `imports` index |
| `output.nix` | Uses `self.homeModules.*` instead of `self.homeManagerModules.*` |
| `programs/yabai/default.nix` | **Custom HM module** — mirrors nix-darwin's `services.yabai` using `launchd.agents` |
| `programs/skhd/default.nix` | Converted from nix-darwin to HM's `services.skhd` |
| `programs/sketchybar/default.nix` | Converted from nix-darwin to HM's `programs.sketchybar` (currently deactivated) |
| `programs/aerospace/default.nix` | Converted from `xdg.configFile` to HM's `programs.aerospace` |
| `programs/alacritty/` | Removed entirely |
| `setups/` | Removed — abstraction added no value |
| `home.nix` | kubectl, kubernetes-helm added back |
| `default.nix` | Removed `./programs/darwin-default.nix` import |

### Active Programs on macair (14 total)

| Group | Programs |
|-------|----------|
| Desktop | yabai, skhd, ghostty, aerospace, pass |
| Dev | neovim, tmux, direnv, starship, taskwarrior, gnupg, pi |
| K8s | k9s |
| Terminal | (shared under dev/desktop) |

### Deactivated Programs

| Program | Status | Reason |
|---------|--------|--------|
| sketchybar | Commented out in `programs/default.nix` and `output.nix` | User deactivated but files kept |
| alacritty | Removed entirely | User requested deletion |

---

## Key Findings & Architecture Decisions

### 1. `setups/` Removed — Flat Aggregation is Simpler

The original plan included a `setups/` directory to compose programs into use-case collections. This was implemented in Phase 3, then removed after review because:

- **flake-parts constraint**: Only one flake-parts module can define `flake.homeManagerModules`. To work around this, all aggregation had to be in `programs/default.nix` anyway, making `setups/` empty placeholders.
- **No real abstraction**: The "compositions" were just import lists with no shared config. With macair as the only Home Manager host, there's nothing to compose *for*.
- **Indirection without value**: Hosts ended up importing programs directly in `output.nix`, bypassing the setup layer entirely.

**Decision**: Keep it flat. `programs/default.nix` defines all individual modules. `output.nix` wires what macair needs directly. If a second host needs grouping later, re-evaluate then.

### 2. Desktop Programs Work as Home Manager Modules

All 4 macOS desktop programs now use Home Manager options (no nix-darwin modules):

| Program | HM Module Type | Notes |
|---------|---------------|-------|
| yabai | Custom `services.yabai` | Uses `launchd.agents` — mirrors nix-darwin's implementation |
| skhd | Official `services.skhd` | Built into HM, no system module needed |
| sketchybar | Official `programs.sketchybar` | Has `config.source + recursive` support |
| aerospace | Official `programs.aerospace` | Has `launchd.enable` built in |

This works because Home Manager on macOS has `launchd.agents` to manage user-level services. System-level `launchd.daemons` would still need nix-darwin, but none of these programs require it.

### 3. Yabai Custom HM Module

Home Manager doesn't have a `services.yabai` module. A custom module was written in `programs/yabai/default.nix` that:

- Defines `services.yabai.{enable, package, config, extraConfig, enableScriptingAddition}`
- Generates a `yabairc` config file from the attribute set
- Manages the yabai process via `launchd.agents.yabai` with `KeepAlive = true`

This mirrors the nix-darwin `services.yabai` API exactly, so configuration syntax is the same.

### 4. `flake.homeModules` — The Proper Dendritic Approach

Early attempts used `flake.homeManagerModules` (an undeclared flake output), which **cannot be merged** across multiple flake-parts modules:

```
The option `flake.homeManagerModules' is defined multiple times while it's expected to be unique.
```

**Solution:** Home Manager provides an official flake-parts module via `inputs.home-manager.flakeModules.home-manager`. It declares `flake.homeModules` and `flake.homeConfigurations` as proper mergeable options.

With this:

- Each program directory becomes its own flake-parts module exporting `flake.homeModules.<name>`
- `programs/default.nix` is just an `imports` index — flake-parts merges all `homeModules` automatically
- No manual aggregation of individual modules needed

This is the proper dendritic pattern: every file is a flake-parts module.

### 5. `self.homeModules.*` Does NOT Cause Circular Dependency

Unlike the old `self.homeManagerModules.*` approach, `self.homeModules.*` is safe to use because the option is declared and mergeable. Each program module defines `flake.homeModules.<name>`, and the host references `self.homeModules.<name>` in the imports list. There's no self-reference because no module reads `self.homeModules` while defining it.

---

## Remaining Work

### Phase 4: Create Host Configurations

```
hosts/macair/default.nix   — Darwin config, system-level
hosts/homelab/default.nix  — NixOS config
hosts/hetzner/default.nix  — NixOS config
```

The `hosts/` directories exist as placeholders. Currently the darwin config lives in:

- `output.nix` — darwinConfigurations.macair definition
- `default.nix` — base system config (users, nix settings, brew-nix)
- `system.nix` — macOS defaults (dock, keyboard, etc.)

These should be consolidated into `hosts/macair/default.nix`.

For NixOS hosts:

- `homelab/` and `hetzner/` directories are active NixOS configs
- They could be moved to `hosts/homelab/` and `hosts/hetzner/`

### Phase 5: Migrate User Configuration (Optional)

```
users/napatsc/default.nix   — Home Manager config
users/napatsc/git.nix       — Git-specific config
users/napatsc/shell.nix     — Shell aliases, env vars
```

Currently `home.nix` at the root contains shell aliases, env vars, and XDG config. This could be migrated to `users/napatsc/`. The `users/napatsc/` directory already exists and is imported in `output.nix`.

### Phase 6: Cleanup

- Remove `output.nix`, `default.nix`, `system.nix`, `home.nix` once their content is migrated
- Update `README.md`
- Full testing on macair

### Other Open Items

| Issue | Status | Notes |
|-------|--------|-------|
| Top-level options (`myconfig`) | Not started | Could replace `extraSpecialArgs` pattern |
| Auto-discovery for programs | Not started | Manual list works fine for 14 programs |
| `programs/skills/` integration | Done | Consumed as both flake input + HM import |
| Overlays migration | Not started | Currently in `overlays/default.nix` |
| brew-nix in flake-parts | Works | Imported via `inputs.brew-nix.darwinModules.default` |

---

## Tips for the Next Agent

### Debugging `nix flake check` vs `darwin-rebuild`

`nix flake check` only validates the Nix language — it doesn't build or activate anything. Always test with `darwin-rebuild switch --flake .` on the actual machine to catch:

- Missing git-tracked paths (Nix flakes require all referenced files be `git add`ed)
- Module option missing errors (only surface during HM activation)
- Launchd agent / service configuration issues

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Path '...' does not exist in Git repository` | File referenced by the config isn't `git add`ed | `git add <path>` |
| `The option ... was accessed but has no value defined` | Module accesses `config` before it's set | Check option dependencies, provide a default |
| `option defined multiple times while it's expected to be unique` | Two modules define the same undeclared flake output | Use a declared option (like `flake.homeModules` from HM flake-parts module) |
| `attribute 'pkgs' missing` | `pkgs` used outside `perSystem` context | Keep `pkgs`-dependent logic inside HM module args |
| `attribute 'secrets-dir' missing` | `secrets-dir` not in `extraSpecialArgs` or module args | Ensure `secrets-dir` is in both `extraSpecialArgs` and the module function signature |

### Git Hygiene

Always `git add` new or modified files before running `darwin-rebuild`. The flake evaluator reads from the Git index, not the working tree. Forgetting this produces confusing "path does not exist" errors.

### Testing Checklist

- [x] `nix flake check` passes
- [x] `darwin-rebuild switch --flake .` works on macair
- [ ] `nix run github:serokell/deploy-rs -- .#homelab` works
- [ ] `nix run github:serokell/deploy-rs -- .#hetzner-sg` works
- [ ] All programs are available in Home Manager
- [ ] Host-specific overrides work as expected

---

## References

- [Dendritic Pattern GitHub](https://github.com/mightyiam/dendritic)
- [flake-parts Documentation](https://flake.parts/)
- [NixOS Wiki: Flake Parts](https://wiki.nixos.org/wiki/Flake_Parts)
- [Dendritic Pattern Discussion](https://discourse.nixos.org/t/the-dendritic-pattern/61271)
- [nix-darwin services.yabai source](https://github.com/LnL7/nix-darwin/blob/master/modules/services/yabai/default.nix)
- [Home Manager Options Reference](https://nix-community.github.io/home-manager/options/home-manager/index.html)
