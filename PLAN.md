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
├── flake.nix              # flake-parts entry point (imports modules, programs)
├── output.nix             # deploy-rs config only
├── modules/               # Feature modules (flake-parts)
│   ├── identity.nix       # User identity options + deferredModule for HM/nixos
│   ├── darwin.nix         # nix-darwin config (reads from flake-parts options)
│   ├── nixos.nix          # NixOS configs (reads from flake-parts options)
│   └── default.nix        # Imports all modules
├── programs/              # Program modules (each exports flake.homeModules.<name>)
│   ├── default.nix        # Imports index
│   ├── git/               # Git tool config (delta, pager, merge style, lfs)
│   ├── shell/             # Zsh + conditional aliases/session vars
│   ├── skills/            # Agent skills (own flake.nix, consumed as input)
│   └── … (16 active program dirs)
├── hosts/                 # Host configurations
│   ├── macair/default.nix               # Darwin config (brew-nix, nix, macOS defaults)
│   ├── homelab/default.nix              # NixOS config (k3s, podman, wireguard)
│   ├── homelab/hardware-configuration.nix
│   ├── hetzner/default.nix              # NixOS config (k3s server, wireguard)
│   └── hetzner/hardware-configuration.nix
├── users/napatsc/         # HM core (packages, SMB mount, sops)
├── overlays/              # Nixpkgs overlays
└── secrets/               # SOPS-nix secrets
```

### Key Milestones

| Phase | Status | Summary |
|-------|--------|---------|
| Phase 1 | ✅ | flake-parts foundation, `output.nix` conversion |
| Phase 2 | ✅ | All 14 programs export via `flake.homeModules.*` |
| Phase 3 | ✅ | Desktop programs converted to HM modules, `setups/` removed, dendritic refactor |
| Phase 4 | ✅ | Host configs (macair, homelab, hetzner) |
| Phase 5 | ✅ | Migrate user config + dendritic refactor (no specialArgs) |
| Phase 6 | ✅ | Cleanup old files, README, testing |

---

## What Changed (Post-Phase 6)

| File/Dir | Change |
|---|---|
| `overlays/` | Removed — no overlays in use |
| `programs/default.nix` | Converted to auto-discovery (uses `builtins.readDir`) |
| `AGENTS.md` | Created — guide for AI agents |

---

## What Changed in Phase 6

| File/Dir | Change |
|---|---|
| `modules/skhd.nix` | Removed — skhd config lives in `programs/skhd/default.nix` |
| `programs/darwin-default.nix` | Removed — unused legacy file |
| `programs/bat/` | Removed — empty placeholder directory |
| `programs/nix-search/` | Removed — empty placeholder directory |
| `programs/tailscale/` | Removed — empty placeholder directory |
| `programs/fastfetch/` | Removed — config file unused (fastfetch installed as package only) |

---

## What Changed in Phase 4

| File/Dir | Change |
|---|---|
| `hosts/macair/default.nix` | Created — merged `default.nix` + `system.nix` into a single darwin host module |
| `default.nix` | Removed — content moved to `hosts/macair/default.nix` |
| `system.nix` | Removed — content moved to `hosts/macair/default.nix` |
| `hosts/homelab/default.nix` | Replaced placeholder — moved from `homelab/configuration.nix` |
| `hosts/homelab/hardware-configuration.nix` | Moved from `homelab/` |
| `hosts/hetzner/default.nix` | Replaced placeholder — moved from `hetzner/configuration.nix` |
| `hosts/hetzner/hardware-configuration.nix` | Moved from `hetzner/` |
| `homelab/` | Removed — content migrated to `hosts/homelab/` |
| `hetzner/` | Removed — content migrated to `hosts/hetzner/` |
| `output.nix` | Updated module paths to `./hosts/<name>` instead of root files |

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

### Active Programs on macair (17 total)

| Group | Programs |
|-------|----------|
| Desktop | yabai, skhd, ghostty, aerospace, pass |
| Dev | neovim, tmux, direnv, starship, taskwarrior, gnupg, pi, git, shell |
| K8s | k9s |
| Agent | skills |

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

### 6. Dendritic Pattern: No specialArgs/extraSpecialArgs

The dendritic pattern ([mightyiam/dendritic](https://github.com/mightyiam/dendritic)) explicitly states:

> "Values share through let bindings and flake-parts options, never through specialArgs or extraSpecialArgs."

**Implementation:**

- User identity defined as flake-parts options in `modules/identity.nix`
- Lower-level modules (nix-darwin, HM) use `deferredModule` type
- Configurations read from `config.*` — no argument passing
- `output.nix` simplified to just deploy-rs

**Before:**

```nix
# SpecialArgs passes values implicitly
specialArgs = { inherit vars; };
extraSpecialArgs = { user = { ... }; };
```

**After:**

```nix
# Values flow through config.*
config.darwin.modules.identity  # nix-darwin reads from flake-parts
config.nixos.modules.identity   # NixOS reads from flake-parts
config.home.modules.git         # HM reads from flake-parts
```

---

## Remaining Work

### Phase 4: Create Host Configurations ✅

All host configs consolidated:

- `hosts/macair/default.nix` — Darwin config (merged from `default.nix` + `system.nix`)
- `hosts/homelab/default.nix` — NixOS config (moved from `homelab/configuration.nix`)
- `hosts/hetzner/default.nix` — NixOS config (moved from `hetzner/configuration.nix`)
- `output.nix` — Updated to reference `./hosts/<name>` paths
- `default.nix`, `system.nix`, `homelab/`, `hetzner/` — Removed

### Phase 5: Migrate User Configuration ✅

User config migrated to dendritic pattern — no specialArgs, all values flow through `config.*`:

| File | Content |
|------|---------|
| `modules/identity.nix` | User identity options (name, email, pgpKey) + deferredModule for HM/nixos |
| `modules/darwin.nix` | nix-darwin config (reads from flake-parts options) |
| `modules/nixos.nix` | NixOS configs (reads from flake-parts options) |
| `modules/default.nix` | Imports all feature modules |
| `programs/git/default.nix` | Git tool config (delta, pager, merge style, lfs) |
| `programs/shell/default.nix` | Zsh + conditional aliases/session vars |
| `users/napatsc/default.nix` | HM core (packages, SMB mount, sops) |

**Changes:**

- `home.nix` deleted from root
- `modules/identity.nix` created — user identity as flake-parts options with `deferredModule`
- `modules/darwin.nix` created — nix-darwin config reads from `config.darwin.modules.*`
- `modules/nixos.nix` created — NixOS configs read from `config.nixos.modules.*`
- `modules/default.nix` updated — imports identity, darwin, nixos modules
- `programs/git/default.nix` simplified — identity moved to modules/identity.nix
- `programs/shell/default.nix` created — zsh, aliases, session vars (conditional on package presence)
- `output.nix` simplified — just deploy-rs (nix-darwin/NixOS configs moved to modules)
- `hosts/macair/default.nix` updated — uses `config.user.username`
- `hosts/homelab/default.nix` updated — uses `config.user.username`, hardcoded secrets path
- `hosts/hetzner/default.nix` updated — uses `config.user.username`, hardcoded secrets path

**Key design decisions:**

1. **No specialArgs/extraSpecialArgs** — Values flow through `config.*` (dendritic pattern)
2. **User identity as flake-parts options** — `modules/identity.nix` defines `options.user.*`
3. **Lower-level modules via `deferredModule`** — nix-darwin/HM configs are option values, not imports
4. **Shell aliases conditional** — `lib.mkIf (hasPackage "...")` so aliases only appear when tools are installed
5. **Secrets path hardcoded** — `../../secrets` in each host (removed `secrets-dir` from specialArgs)

### Phase 6: Cleanup ✅

- [x] `home.nix` removed
- [x] `README.md` updated
- [x] Remove unused `modules/skhd.nix`
- [x] Remove unused `programs/darwin-default.nix`
- [x] Remove empty placeholder directories (`bat`, `nix-search`, `tailscale`, `fastfetch`)
- [x] `nix flake check` passes
- [x] Full testing on macair (`sudo darwin-rebuild switch --flake .`)
- [x] Test deploy-rs on homelab/hetzner

### Other Open Items

| Issue | Status | Notes |
|-------|--------|-------|
| Top-level options (`myconfig`) | Done | Replaced with `options.user.*` in `modules/identity.nix` |
| `extraSpecialArgs` removal | Done | All values flow through `config.*` (dendritic pattern) |
| `specialArgs` removal | Done | All values flow through `config.*` |
| Auto-discovery for programs | Done | `programs/default.nix` auto-discovers directories |
| `programs/skills/` integration | Done | Consumed as both flake input + HM import |
| Overlays removal | Done | Removed — no overlays in use |
| brew-nix in flake-parts | Done | Imported via `inputs.brew-nix.darwinModules.default` |
| AGENTS.md | Done | Guide for AI agents working on this repo |

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
| `module does not look like a module` | Importing a list instead of a module | Ensure imports return attribute sets, not lists |

### Git Hygiene

Always `git add` new or modified files before running `darwin-rebuild`. The flake evaluator reads from the Git index, not the working tree. Forgetting this produces confusing "path does not exist" errors.

### Testing Checklist

- [x] `nix flake check` passes (all configs validated)
- [x] `darwin-rebuild switch --flake .` works on macair
- [x] Host configs consolidated to `hosts/<name>/`
- [x] `nix run github:serokell/deploy-rs -- .#homelab` works
- [x] `nix run github:serokell/deploy-rs -- .#hetzner-sg` works
- [x] All programs are available in Home Manager
- [x] Host-specific overrides work as expected

---

## References

- [Dendritic Pattern GitHub](https://github.com/mightyiam/dendritic)
- [flake-parts Documentation](https://flake.parts/)
- [NixOS Wiki: Flake Parts](https://wiki.nixos.org/wiki/Flake_Parts)
- [Dendritic Pattern Discussion](https://discourse.nixos.org/t/the-dendritic-pattern/61271)
- [nix-darwin services.yabai source](https://github.com/LnL7/nix-darwin/blob/master/modules/services/yabai/default.nix)
- [Home Manager Options Reference](https://nix-community.github.io/home-manager/options/home-manager/index.html)
