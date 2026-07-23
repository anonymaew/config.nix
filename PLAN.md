# Nix Configuration Refactoring Plan

## Handoff Summary

**Date:** 2026-07-23
**User:** napatsc
**Workspace:** `/Users/napatsc/code/nix`
**Goal:** Refactor Nix configuration to follow the dendritic pattern using flake-parts

---

## Current State

### Phase 1 Complete — Foundation Laid

**Completed by:** Agent on 2026-07-23
**Status:** `nix flake check` passes ✅, `nix flake show` correct ✅

### Post-Phase 1 Structure

```
.
├── flake.nix              # flake-parts entry point (NEW)
├── output.nix             # Converted to flake-parts module
├── programs/
│   ├── default.nix        # Auto-discovery skeleton (currently empty)
│   ├── darwin-default.nix # ← still used by default.nix
│   ├── skills/            # Has own flake.nix — excluded from discovery
│   └── … (21 program dirs, still old-format)
├── setups/                # NEW — 5 category dirs, all placeholders
│   ├── default.nix
│   ├── desktop/
│   ├── dev/
│   ├── kubernetes/
│   ├── self-hosted/
│   └── server/
├── hosts/                 # NEW — 3 host dirs, all placeholders
│   ├── macair/
│   ├── homelab/
│   └── hetzner/
├── default.nix            # Still active (darwin base config)
├── system.nix             # Still active (macOS defaults)
├── home.nix               # Still active (Home Manager, imports programs)
├── users/napatsc/         # Still active
├── homelab/               # Still active (NixOS)
├── hetzner/               # Still active (NixOS)
├── modules/
├── overlays/
└── secrets/
```

### What Changed in Phase 1

| File/Dir | Change |
|---|---|
| `flake.nix` | Rewritten: delegates to `flake-parts.lib.mkFlake` instead of `import ./output.nix` |
| `output.nix` | Converted to flake-parts module (wraps outputs in `perSystem` + `flake` blocks) |
| `programs/default.nix` | **Created** — auto-discovery skeleton, currently empty |
| `setups/` | **Created** — 5 category directories with placeholder `default.nix` |
| `hosts/` | **Created** — 3 host directories with placeholder `default.nix` |
| `flake.lock` | Added `flake-parts` direct input |

### Key Issues (Still Open)

1. **Manual wiring** still in `output.nix` — will be dissolved into programs/setups/hosts in Phases 2-4
2. **Programs still old-format** — imported directly by home.nix, not exposing `flake.homeManagerModules.*`
3. **No top-level options yet** — no `myconfig` namespace defined
4. **No setups populated** — all placeholders until Phase 3
5. **Host dirs are empty** — all placeholders until Phase 4
6. **services/flake-parts** pattern not used yet (perSystem.flakeModules)

---

## Research: Dendritic Pattern

### What is the Dendritic Pattern?

A Nixpkgs module system usage pattern where:

1. **Every file is a module** - except entry points (`flake.nix`, `default.nix`)
2. **Top-level configuration** - uses flake-parts to manage all outputs
3. **Feature-centric** - organize by aspect, not by host
4. **Cross-cutting concerns** - handled via top-level options
5. **Automatic discovery** - adding files makes them available

### Key Resources

- [mightyiam/dendritic](https://github.com/mightyiam/dendritic) - Official pattern documentation
- [flake-parts documentation](https://flake.parts/) - Module system reference
- [NixOS Wiki: Flake Parts](https://wiki.nixos.org/wiki/Flake_Parts) - Official recommendation

### flake-parts Status

- **Officially recommended** over flake-utils by NixOS Wiki
- **1.4K+ GitHub stars**, actively maintained by Hercules CI
- **De facto standard** for complex Nix flakes
- **Required** for dendritic pattern implementation

---

## Agreed Principles

### 1. Use flake-parts for Top-Level Configuration

- Replace `output.nix` manual wiring with flake-parts module system
- Enable automatic module discovery
- Support multi-system outputs

### 2. Aspect-Oriented `programs/` Directory

- Each program = one aspect (one directory)
- Each program exports `flake.homeManagerModules.<name>` (and optionally `flake.nixosModules.<name>`)
- One file per program, multiple targets

### 3. Composition via `setups/` Directory

- `setups/` = collections of programs for specific use cases
- Categories: `desktop/`, `dev/`, `kubernetes/`, `self-hosted/`, `server/`
- Hosts select which setup(s) to use

### 4. Top-Level Options for Cross-Cutting Concerns

- Shared config in `flake.nix` or `top-level.nix`
- Feature flags: `myconfig.features.desktop`, `myconfig.features.kubernetes`, etc.
- All modules can read via `specialArgs`

### 5. Host Files as Thin Wrappers

- Hosts only specify: which setup(s) + host-specific overrides
- No program configuration in hosts
- Clear hierarchy: options → programs → setups → hosts

### 6. Declarative Module Discovery

- Use flake-parts to auto-import directories
- No manual import lists
- Adding a file automatically makes it available

---

## Target Directory Structure

```
.
├── flake.nix                      # Top-level entry point with flake-parts
├── flake.lock
├── README.md
│
├── programs/                      # Individual program aspects
│   ├── aerospace/
│   │   ├── default.nix           # Main module (auto-discovered)
│   │   └── aerospace.toml        # Config files
│   ├── neovim/
│   │   ├── default.nix
│   │   └── init.lua
│   ├── tmux/
│   │   ├── default.nix
│   │   └── tmux.conf
│   ├── ghostty/
│   ├── direnv/
│   ├── starship/
│   ├── k9s/
│   └── ... (all 21 programs)
│
├── setups/                        # Program compositions by category
│   ├── desktop/                   # GUI/window manager setup
│   │   └── default.nix
│   ├── dev/                       # Development environment
│   │   └── default.nix
│   ├── kubernetes/                # K8s development setup
│   │   └── default.nix
│   ├── self-hosted/               # Homelab services
│   │   └── default.nix
│   └── server/                    # Minimal server setup
│       └── default.nix
│
├── hosts/                         # Machine-specific configs
│   ├── macair/
│   │   └── default.nix           # Darwin system + setups selection
│   ├── homelab/
│   │   └── default.nix           # NixOS + setups selection
│   └── hetzner/
│       └── default.nix           # NixOS + setups selection
│
├── users/                         # User-specific configs
│   └── napatsc/
│       ├── default.nix           # Home Manager config
│       ├── git.nix               # Git-specific config
│       └── shell.nix             # Shell aliases, env vars
│
├── modules/                       # Shared NixOS/darwin modules
│   ├── samba.nix
│   ├── monitoring.nix
│   └── networking.nix
│
├── overlays/                      # Nixpkgs overlays
│   └── default.nix
│
└── secrets/                       # SOPS-nix secrets
    ├── .sops.yaml
    └── keys/
```

---

## Migration Plan

### Phase 1: Foundation Setup ✅ (Completed 2026-07-23)

**What was done:**

1. Created new `flake.nix` with flake-parts
2. Created directory structure (`setups/`, `hosts/`)
3. Created `programs/default.nix` for auto-discovery (currently empty)
4. Created `setups/default.nix` (imports all 5 sub-categories)
5. Converted `output.nix` to a flake-parts module
6. Verified `nix flake check` passes ✅

**Key decisions made:**

- flake-parts is used as `outputs = inputs@{ flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } { ... }`
- `systems = [ "aarch64-darwin" "x86_64-linux" ]` covers both Mac and NixOS
- The `output.nix` wraps existing outputs: `perSystem.formatter` + `flake.{darwinConfigurations,nixosConfigurations,deploy}`
- `programs/default.nix` intentionally empty — programs will be migrated one at a time in Phase 2
- `setups/` and `hosts/` are placeholders — actual content comes in Phase 3 and Phase 4
- `programs/skills/` is excluded from discovery because it has its own `flake.nix` and is consumed as a separate flake input (`agent-skills`)

### Phase 2: Migrate Programs (One at a Time)

For each program:

1. Convert to flake-parts module format
2. Add `flake.homeManagerModules.<name>` export
3. Add `flake.nixosModules.<name>` if applicable
4. Update `programs/default.nix` to include
5. Test with `nix flake check`

**Recommended order:**

1. tmux, ghostty, starship (terminal programs)
2. neovim, direnv (dev tools)
3. aerospace, k9s, pi
4. Remaining programs

### Phase 3: Create Setups

1. `setups/desktop/default.nix` - Desktop environment
2. `setups/dev/default.nix` - Development tools
3. `setups/kubernetes/default.nix` - K8s development
4. `setups/self-hosted/default.nix` - Homelab services
5. `setups/server/default.nix` - Minimal server

### Phase 4: Create Host Configurations

1. `hosts/macair/default.nix` - Darwin system
2. `hosts/homelab/default.nix` - NixOS server
3. `hosts/hetzner/default.nix` - NixOS server

### Phase 5: Migrate User Configuration

1. `users/napatsc/default.nix` - Home Manager
2. `users/napatsc/git.nix` - Git config
3. `users/napatsc/shell.nix` - Shell config

### Phase 6: Cleanup

1. Remove old files: `output.nix`, `default.nix`, `system.nix`, `home.nix`
2. Update `README.md`
3. Full testing

---

## Example Migration: tmux

### Current (`programs/tmux/default.nix`)

```nix
{ pkgs, ... }:
let
  sharedConfig = ./tmux.conf;
in
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    terminal = "xterm-ghostty";
    plugins = [ ];
    baseIndex = 1;
    escapeTime = 10;
    focusEvents = true;
    extraConfig = ''
      set -g status-right '#{user}@#h  %H:%M'
      set -g @nix_tmux 1
      run '${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux'
      run '${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/resurrect.tmux'
      source-file ${sharedConfig}
    '';
  };
}
```

### New (`programs/tmux/default.nix`)

```nix
{ inputs, ... }:
{
  # Home Manager module
  flake.homeManagerModules.tmux = { pkgs, config, myconfig, ... }: {
    programs.tmux = {
      enable = true;
      keyMode = "vi";
      terminal = "xterm-ghostty";
      plugins = [ ];
      baseIndex = 1;
      escapeTime = 10;
      focusEvents = true;
      extraConfig = ''
        set -g status-right '#{user}@#h  %H:%M'
        set -g @nix_tmux 1
        run '${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux'
        run '${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/resurrect.tmux'
        source-file ${./tmux.conf}
      '';
    };
  };
  
  # NixOS module (for servers)
  flake.nixosModules.tmux = { pkgs, ... }: {
    programs.tmux.enable = true;
    environment.systemPackages = [ pkgs.tmux ];
  };
}
```

---

## Example: Top-Level Options

```nix
# flake.nix
{
  options = {
    myconfig = {
      username = inputs.nixpkgs.lib.mkOption {
        type = inputs.nixpkgs.lib.types.str;
        default = "napatsc";
      };
      features = {
        desktop = inputs.nixpkgs.lib.mkEnableOption "desktop environment";
        kubernetes = inputs.nixpkgs.lib.mkEnableOption "kubernetes support";
        monitoring = inputs.nixpkgs.lib.mkEnableOption "monitoring stack";
      };
    };
  };
  
  config = {
    myconfig.username = "napatsc";
    myconfig.features.desktop = true;
    myconfig.features.kubernetes = true;
  };
}
```

### Usage in Modules

```nix
# programs/tmux/default.nix
{ myconfig, ... }:
{
  flake.homeManagerModules.tmux = { pkgs, ... }: {
    # Can use myconfig.username if needed
    programs.tmux = { ... };
  };
}
```

---

## Example: Setup Composition

```nix
# setups/desktop/default.nix
{ inputs, myconfig, ... }:
{
  # NixOS/Darwin module for desktop
  flake.nixosModules.desktop = { config, ... }: {
    imports = [
      inputs.self.nixosModules.tmux
    ];
    
    myconfig.features.desktop = true;
    
    services.xserver.enable = true;
  };
  
  # Home Manager module for desktop
  flake.homeManagerModules.desktop = { config, ... }: {
    imports = [
      inputs.self.homeManagerModules.aerospace
      inputs.self.homeManagerModules.tmux
      inputs.self.homeManagerModules.ghostty
      inputs.self.homeManagerModules.starship
      inputs.self.homeManagerModules.neovim
    ];
    
    xdg.enable = true;
  };
}
```

---

## Example: Host Configuration

```nix
# hosts/macair/default.nix
{ inputs, myconfig, ... }:
{
  flake.darwinConfigurations.macair = { config, ... }: {
    imports = [
      # Use setups
      inputs.self.nixosModules.desktop
      inputs.self.homeManagerModules.desktop
      inputs.self.homeManagerModules.dev
      inputs.self.homeManagerModules.kubernetes
      
      # Host-specific modules
      ../../modules/networking.nix
    ];
    
    # Host-specific overrides
    myconfig.username = "napatsc";
    myconfig.features.monitoring = false;
    
    # Darwin-specific config
    system.stateVersion = 7;
    services.nix-daemon.enable = true;
  };
}
```

---

---

## Phase 1 Implementation Details (For Future Agents)

### flake.nix Structure

```nix
{
  inputs = { /* … all inputs … flake-parts.url = "github:hercules-ci/flake-parts"; */ };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-linux" ];

      imports = [
        ./output.nix     # Existing darwin/nixos/deploy outputs
        ./programs       # Auto-discovered program modules
        ./setups         # Setup compositions
      ];
    };
}
```

### flake-parts Module Format (output.nix)

A flake-parts module is `{ self, inputs, ... }: { perSystem = …; flake = …; }`:

- `perSystem` — runs once per system in `systems` list (formatter, packages, devShells)
- `flake` — top-level flake outputs (darwinConfigurations, nixosConfigurations, deploy, etc.)
- Use `inputs.nixpkgs` not bare `nixpkgs` (they're in `inputs` now)
- `self` still refers to the final flake (same as before)

```nix
{ self, inputs, ... }:
let
  deployPkgs = (inputs.nixpkgs.legacyPackages.x86_64-linux).extend (
    final: prev: {
      deploy-rs = {
        inherit (prev) deploy-rs;
        lib = inputs.deploy-rs.lib.x86_64-linux;
      };
    }
  );
in {
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixfmt-rfc-style;
  };

  flake = {
    darwinConfigurations.macair = inputs.nix-darwin.lib.darwinSystem { … };
    nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem { … };
    nixosConfigurations.hetzner-sg = inputs.nixpkgs.lib.nixosSystem { … };
    deploy.nodes.homelab = { path = deployPkgs.deploy-rs.lib.activate.nixos …; };
    deploy.nodes.hetzner-sg = { … };
  };
}
```

### Git Tracking Requirement

Nix flakes require that referenced files are **tracked by Git**. Newly created files will cause `nix flake check` errors like:

```
error: Path 'programs/default.nix' in the repository is not tracked by Git.
```

Fix with `git add <new-files>` before checking.

### deploy Warning is Harmless

`nix flake check` warns `unknown flake output 'deploy'` because `deploy` is a custom output for deploy-rs. This does NOT affect functionality — it's just Nix not recognizing the non-standard output name.

### program/skills Exclusion

The `programs/skills/` directory has its own `flake.nix` and is consumed as a separate flake input (`agent-skills` pointing to `path:./programs/skills`). It must NOT be imported as a flake-parts module. The auto-discovery mechanism must exclude it or skip directories with their own `flake.nix`.

Currently `programs/default.nix` is a manual list (empty in Phase 1). When auto-discovery is enabled later, filter out `skills` by checking for `flake.nix` or excluding it explicitly.

### Program Migration Pattern (for Phase 2)

Each program must be converted from a plain Home Manager module like:

```nix
{ pkgs, ... }: { programs.tmux = { enable = true; … }; }
```

To a flake-parts module that exports the Home Manager module:

```nix
{ inputs, ... }: {
  flake.homeManagerModules.tmux = { pkgs, ... }: {
    programs.tmux = { enable = true; … };
  };
  # Optional: NixOS module for servers
  flake.nixosModules.tmux = { pkgs, ... }: {
    programs.tmux.enable = true;
    environment.systemPackages = [ pkgs.tmux ];
  };
}
```

Then add `./tmux` to `programs/default.nix` imports.

When a program is migrated, also REMOVE its import from `home.nix` (which currently imports it directly as a Home Manager module) and replace with `inputs.self.homeManagerModules.tmux`.

---

## Suggested Skills

The next agent should invoke these skills:

1. **pi-lens-ast-grep** - For searching and replacing code patterns during migration
   - Location: `/Users/napatsc/.pi/agent/git/github.com/apmantza/pi-lens/skills/pi-lens-ast-grep/SKILL.md`
   - Use for: Finding all program modules, verifying migration patterns

2. **pi-lens-lsp-navigation** - For code intelligence and type/error checks
   - Location: `/Users/napatsc/.pi/agent/git/github.com/apmantza/pi-lens/skills/pi-lens-lsp-navigation/SKILL.md`
   - Use for: Verifying Nix syntax, checking for errors after migration

3. **tdd** - For test-driven development approach
   - Location: `/Users/napatsc/.agents/skills/tdd/SKILL.md`
   - Use for: Writing tests before/during migration to ensure correctness

---

## Open Questions / Decisions Needed

1. **Overlays handling**: How to migrate `overlays/default.nix` to flake-parts?
2. **Secrets management**: How to structure SOPS-nix in the new pattern?
3. **agent-skills integration**: How to handle the `programs/skills/` flake input?
4. **brew-nix integration**: How to structure brew-nix in flake-parts?
5. **deploy-rs**: Where should deploy-rs configuration live?
6. **specialArgs vs top-level options**: Should `myconfig` use flake-parts options (`options.myconfig`) or keep using `specialArgs`? The dendritic pattern uses options, but `specialArgs` is also valid and simpler.
7. **Auto-discovery mechanism**: Should `programs/default.nix` switch to `builtins.readDir` + `lib.filterAttrs` for full auto-discovery, or stay with a manual list? Manual is safer (avoids picking up unconverted programs).

---

## Testing Checklist

- [x] `nix flake check` passes (Phase 1 ✅)
- [x] `nix flake show` shows all outputs correctly (Phase 1 ✅)
- [ ] `darwin-rebuild switch --flake .` works on macair
- [ ] `nix run github:serokell/deploy-rs -- .#homelab` works
- [ ] `nix run github:serokell/deploy-rs -- .#hetzner-sg` works
- [ ] All programs are available in Home Manager
- [ ] All setups compose correctly
- [ ] Host-specific overrides work as expected

---

## Timeline (Estimated)

- **Week 1 (Done ✅):** Foundation setup completed 2026-07-23
- **Week 1-2:** Migrate 5-6 programs (Phase 2)
- **Week 3:** Migrate remaining programs + create setups (Phase 2-3)
- **Week 4:** Create host configurations + migrate user config (Phase 4-5)
- **Week 5:** Cleanup + testing + documentation (Phase 6)

---

## Notes

- The user prefers **feature-centric** organization over host-centric
- The user wants **`setups/`** directory for program compositions
- The user wants **`users/`** directory for user-specific configs (just napatsc for now)
- The user confirmed **flake-parts** is the right choice (officially recommended)
- The user understands that **top-level options** are part of the dendritic pattern, not a contradiction
- Phase 1 flake.nix still imports output.nix — output.nix IS the second module entry in `imports`
- `programs/skills/` is an awkward edge case: it serves as BOTH a flake input (with its own flake.nix) AND a Home Manager module directory. Leave it as-is; it's consumed via both `agent-skills` input and `./programs/skills` import.

---

## References

- [Dendritic Pattern GitHub](https://github.com/mightyiam/dendritic)
- [flake-parts Documentation](https://flake.parts/)
- [NixOS Wiki: Flake Parts](https://wiki.nixos.org/wiki/Flake_Parts)
- [Dendritic Pattern Discussion](https://discourse.nixos.org/t/the-dendritic-pattern/61271)
