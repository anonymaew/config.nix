# Structuring a multi-machine Nix flake

Research notes + a concrete plan for this repo. The goal is **tidy, low-verbosity,
easily extensible**: adding a machine or a program should be *one* small change,
and per-machine divergence should be data, not copy-paste.

TL;DR of the conclusion at the end: keep flake-parts + dendritic modules, add a
single **host registry** (`hosts/default.nix`, data only), give every host a
`my.host` option that modules gate on, and make program selection
"all by default, subtract per host". No rewrite required.

---

## 1. The four questions every multi-host flake answers

Whatever the directory names, every real config answers these four. Comparing
projects is mostly comparing how they answer them.

| # | Question | Typical answers |
| --- | --- | --- |
| 1 | **Where is the list of hosts?** | a central table, one file per host merged by `mergeAttrsList`, or full auto-discovery of a directory |
| 2 | **How does a host pick up shared config?** | `imports` with relative paths; `common/core` + `common/optional`; profiles/suites; aspects (`provides`/`includes`) |
| 3 | **How does one program differ per machine?** | `lib.mkIf` on a platform/host predicate; per-platform files inside the program dir; a `profile` option; aspect composition |
| 4 | **How do user (home-manager) configs attach to a host?** | inline `home-manager.users.<u>.imports`; `home/<user>/<host>/`; `home/<user>@<host>` attribute names |

Almost all disagreement is about #3, because it is the one that is **not** forced
by the module system.

---

## 2. Survey of real, currently-maintained layouts

### 2.1 Misterio77 — the "canonical" structured layout

`github:Misterio77/nix-config` (a.k.a. Foundry). No flake-parts; plain
`outputs = inputs: { nixosConfigurations = { … } }` with
`lib.nixosSystem { modules = [ ./hosts/nixos/atlas ]; }` per host.

```text
hosts/
  nixos/atlas/default.nix      # imports common + optional, sets hostName
  common/
    global/                    # core: present on every host (a "hard rule")
    users/<user>/              # host-level user account + keys
    optional/*.nix             # opt-in features (pipewire, cups, wireless, …)
home/
  <user>/<host>/               # per-host home-manager config
modules/{nixos,home-manager,system-manager}/
overlays/ pkgs/ lib/
```

The host file is just an import list plus the genuinely host-specific values:

```nix
# hosts/nixos/atlas/default.nix
{ pkgs, inputs, ... }: {
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    ./hardware-configuration.nix
    ../common/global
    ../common/users/gabriel
    ../common/optional/peripherals.nix
    ../common/optional/pipewire.nix
    ../common/optional/wireless.nix
  ];
  networking.hostName = "atlas";
  system.stateVersion = "22.05";
}
```

**Strengths:** dead simple, no framework, every host is readable in 20 lines.
**Cost:** `flake.nix` and each host's import list grow linearly; renaming a
shared module touches N files.

### 2.2 EmergentMind — same bones, hardened with conventions

`github:EmergentMind/nix-config`. Same `hosts/common/{core,optional}` idea, but:
one `mkHost` helper in `flake.nix`, hosts auto-discovered with
`lib.readDir ./hosts/nixos`, a `lib.custom` (`introdus`) exposing
`relativeToRoot` and `scanPaths`, and a per-host `host-spec.nix` holding the
machine's facts (IPs, ports, monitor list, users) so modules can read
`config.hostSpec.*` instead of hardcoding.

```nix
# hosts/nixos/ghost/default.nix
imports = lib.flatten [
  (lib.custom.scanPaths ./.)                      # every *.nix in this dir
  (map lib.custom.relativeToRoot (
    [ "hosts/common/core" ]
    ++ map (f: "hosts/common/optional/${f}") [
         "services/openssh.nix" "gaming.nix" "fonts.nix" "yubikey.nix" ]))
];
```

and an explicit optional-over-the-top rule in the README: *"core = present on
all hosts, this is a hard rule; if something isn't core, it is optional."*

**Strengths:** the `core`/`optional` split is a real editorial rule that keeps
shared code honest; `hostSpec` kills magic strings.
**Cost:** a lot of machinery (`introdus`, `relativeToRoot`, `scanPaths`) for
what is ultimately relative imports; the repo is consciously a reference
implementation, not a minimal one.

### 2.3 ryan4yin — one file per host, no central list

`github:ryan4yin/nix-config`. `flake.nix` is only
`outputs = inputs: import ./outputs inputs;`. Then:

```text
outputs/
  aarch64-darwin/default.nix     # haumea.lib.load ./src; mergeAttrsList
  aarch64-darwin/src/fern.nix    # → { darwinConfigurations.fern = …; }
  x86_64-linux/src/<host>.nix    # → { nixosConfigurations.<host> = …; }
hosts/<host>/                    # system-level modules
home/
  base/{core,gui,tui}/           # shared user config
  linux/ darwin/                 # OS-wide user config
  hosts/{linux,darwin}/<host>.nix  # per-host user config
```

Each host file declares its module lists and hands them to a small lib helper,
so the *shape* is uniform and there is no registry to keep in sync:

```nix
# outputs/aarch64-darwin/src/fern.nix
{ inputs, lib, mylib, system, genSpecialArgs, ... }@args:
let name = "fern"; in {
  modules = {
    darwin-modules = map mylib.relativeToRoot [ "modules/darwin" "hosts/darwin-${name}" ];
    home-modules   = map mylib.relativeToRoot [ "home/hosts/darwin/darwin-${name}.nix" ];
  };
}
// { darwinConfigurations.${name} = mylib.macosSystem (that // args); }
```

Per-machine user divergence is a 5-line file:

```nix
# home/hosts/darwin/darwin-fern.nix
{ config, ... }: {
  imports = [ ../../darwin ];
  programs.ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/fern";
}
```

**Strengths:** adding a host = add one file; zero central bookkeeping; the
`base` / `<os>` / `hosts/<host>` three-layer split for home-manager is the
tidiest per-machine story of the four.
**Cost:** every host repeats ~10 lines of boilerplate; `haumea` + lazy `args`
means "you can't delete arguments you don't use" (a real gotcha, and a source
of confusing errors).

### 2.4 drupol/infra — dendritic + aspect-oriented (`den`)

`github:drupol/infra`. `flake.nix` is auto-generated by `flake-file` and is
literally two lines of logic:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

Every file under `modules/` is a flake-parts module; one *aspect* file can
supply the same feature to NixOS, darwin and home-manager at once:

```nix
# modules/bluetooth/default.nix
{ den, ... }: {
  den.aspects.bluetooth = {
    nixos.hardware.bluetooth.enable = true;
  };
}
```

and a host declares itself + which aspects its users get:

```nix
# modules/hosts/x13/default.nix
{ den, inputs, ... }: {
  den.aspects.x13 = {
    nixos = { imports = [ inputs.nixos-hardware.nixosModules.common-pc-ssd ]; /* … */ };
    provides.to-users.includes = with den.aspects; [
      base bluetooth desktop dev sound vpn fwupd (facter ./facter.json) root
    ];
  };
  den.hosts.x86_64-linux.x13.users.pol = { };
}
```

**Strengths:** the best answer to "one program, several classes, several
machines": an aspect is reused by *inclusion*, not by path. No import lists
anywhere.
**Cost:** you adopt `den`'s vocabulary (`aspects`, `provides`, `includes`,
`classes`) and a young, fast-moving dependency; every file becomes
flake-parts-shaped, which is excellent for policy and awkward for "just give me
the hardware config".

### 2.5 Plain `flake-parts` + `import-tree` (the minimal dendritic setup)

If you like 2.4's structure but not a framework:

```nix
# flake.nix
{ inputs, ... }:
{
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
```

`imports = [ … 20 files … ]` disappears entirely; `_`-prefixed directories are
skipped (a place for helpers). This is the pattern's own recommendation — the
[Dendritic spec](https://github.com/mightyiam/dendritic) is only "every file
that is not an entry point is a module of the top-level configuration".

### 2.6 nixos-unified — framework that unifies the three classes

`numtide/nixos-unified`: a flake-parts module that unifies NixOS + nix-darwin +
home-manager behind one interface (`nixos-unified.lib.mkFlake`), with
`cfg = { nixos, darwin, home }` inside a single module. Attractive if you want
the *same* module to configure all three classes without den's aspect DSL.
Trade-off: a fairly opinionated layer between you and `lib.nixosSystem`, and the
project's momentum is low compared to flake-parts itself.

### 2.7 digga / devos — do not adopt

`divnix/digga` pioneered "profiles & suites" but its README now opens with:

> DEPRECATION NOTICE: This project is no longer maintained and not recommended
> for any sort of use case.

Mentioned only because it still shows up in search results. Its ideas (a named
*suite* = a curated bundle of profiles) are worth stealing; the dependency is not.

---

## 3. Comparison

| | central host list | shared config | per-machine program config | auto-discovery | deps |
| --- | --- | --- | --- | --- | --- |
| Misterio77 | yes (`flake.nix`) | `common/global` + `optional/*` | per-host `home/<u>/<host>/` | no | none |
| EmergentMind | generated from dir | `common/core` + `optional/*`, `hostSpec` | per-host dirs + optional modules | yes (`readDir`) | introdus |
| ryan4yin | per-file, merged | `base` / `<os>` / `hosts/<h>` | `home/hosts/<os>/<h>.nix` | yes (haumea) | haumea |
| drupol | per-file (`den.hosts.*`) | aspects + `provides.includes` | aspects, per class | yes (import-tree) | den, flake-file |
| this repo (today) | hardcoded ×2 | `modules/` + `flake.homeModules` | **none yet** | programs only | flake-parts |

---

## 4. Where this repo actually hurts

Not style opinions — specific files:

1. **`modules/darwin.nix` hardcodes `macair`.** A second Mac = copy the whole
   `darwinSystem` block. `modules/nixos.nix` already has the right shape
   (`mkHost { host; extraModules; }` + a list of three calls) — darwin should
   look the same.
2. **The host list exists in three places**: `modules/darwin.nix`,
   `modules/nixos.nix`, and `output.nix` (`deploy.nodes.<host>` with IPs).
   Adding `homelab-x` means three edits, one of which (deploy) is easy to forget.
3. **No per-machine program selection.** `modules/darwin.nix` does
   `++ lib.attrValues self.homeModules` — every program lands on every
   home-manager host, unconditionally. That is the correct *default* (zero-touch
   when adding a program) but there is currently no way to say "not `comfyui`
   on the work laptop".
4. **No host identity inside modules.** Nothing lets `programs/neovim` know
   which machine it is on except `pkgs.stdenv.isDarwin`, so any per-machine
   difference would become scattered `networking.hostName == "macair"` checks.
5. **`modules/identity.nix` mixes schema and content**: it declares
   `options.user` (good) and *also* defines `config.home.modules.git` and
   `config.nixos.modules.identity` (content that belongs in `programs/git` and a
   `users/` module). Fine today; confusing once there are two users.
6. **NixOS hosts have no home-manager at all** (`modules/nixos.nix` never
   imports `home-manager.nixosModules.home-manager`). The first time you want
   `kubectl`/`git` config on `homelab-n150`, this becomes an architecture
   decision — so decide it now, with the registry, instead of ad hoc.
7. Minor: `AGENTS.md` says "never use `specialArgs`" while `modules/*.nix`
   passes `user` through it. Pick a rule and write it down (see §6.4).

---

## 5. Recommended target layout for this repo

Two small additions, no rewrite. Everything below keeps the existing dendritic
flavour (`config.*` flow, `lib.types.deferredModule`, auto-discovered programs).

### 5.1 One data-only host registry

```nix
# hosts/default.nix — the ONLY list of machines in the repo
{ lib, ... }:
{
  options.hosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        class = lib.mkOption { type = lib.types.enum [ "darwin" "nixos" ]; };
        system = lib.mkOption { type = lib.types.str; };
        tags = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
        # null = every auto-discovered program (the default, zero-touch)
        excludePrograms = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
        extraModules = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = [ ]; };
        deploy = lib.mkOption { type = lib.types.nullOr (lib.types.submodule { /* hostname, sshUser, user, interactiveSudo */ }); default = null; };
      };
    }));
    default = { };
  };

  config.hosts = {
    macair       = { class = "darwin"; system = "aarch64-darwin"; tags = [ "gui" "dev" "laptop" ]; };
    homelab-n150 = { class = "nixos";  system = "x86_64-linux";  tags = [ "server" "k8s" ];
                     deploy = { hostname = "100.89.132.36"; sshUser = "root"; user = "root"; interactiveSudo = false; }; };
    homelab-3070 = { class = "nixos";  system = "x86_64-linux";  tags = [ "server" "k8s" ];
                     extraModules = [ "disko" ];
                     deploy = { hostname = "100.83.20.73"; sshUser = "root"; user = "root"; interactiveSudo = false; }; };
    linode-us    = { class = "nixos";  system = "x86_64-linux";  tags = [ "server" "ingress" ];
                     deploy = { hostname = "45.33.39.244"; sshUser = "root"; user = "root"; interactiveSudo = true; }; };
  };
}
```

This is *data*, not logic — which is why it is the one place a new host must be
mentioned. Everything else (outputs, deploy nodes, program selection) is derived
from it. `hosts/<name>/` still holds the actual modules.

### 5.2 One builder, two thin wrappers

```nix
# modules/hosts.nix (replaces the hardcoded parts of darwin.nix + nixos.nix)
{ self, inputs, config, lib, ... }:
let
  root = ../.;
  # flake-facts are needed *before* a module system exists → pass them in.
  hostArgs = name: host: {
    _module.args.host = { inherit name; inherit (host) class system tags; };
    _module.args.user = config.user;
  };

  mkDarwin = name: host: inputs.nix-darwin.lib.darwinSystem {
    inherit (host) system;
    modules = [
      (root + "/hosts/${name}")
      (hostArgs name host)
      inputs.determinate.darwinModules.default
      inputs.brew-nix.darwinModules.default
      inputs.mac-app-util.darwinModules.default
      inputs.sops-nix.darwinModules.sops
      inputs.home-manager.darwinModules.home-manager
      # identity + per-host program filtering + HM user
      config.darwin.modules.identity
      config.darwin.modules.home
    ] ++ host.extraModules;
  };

  mkNixos = name: host: inputs.nixpkgs.lib.nixosSystem {
    inherit (host) system;
    modules = [
      (root + "/hosts/${name}")
      (hostArgs name host)
      inputs.determinate.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      config.nixos.modules.base
      config.nixos.modules.identity
    ] ++ host.extraModules;
  };

  by = pred: lib.mapAttrs (n: h: (if h.class == "darwin" then mkDarwin else mkNixos) n h)
                          (lib.filterAttrs (_: pred) config.hosts);
in
{
  config.flake.darwinConfigurations = by (h: h.class == "darwin");
  config.flake.nixosConfigurations  = by (h: h.class == "nixos");
}
```

`extraModules` stays a list of real modules (the input, e.g.
`inputs.disko.nixosModules.disko`, is why this is defined in a file that has
`inputs` in scope).

### 5.3 Program selection: all by default, subtract per host

```nix
# modules/darwin.nix — the home-manager wiring, now host-agnostic
config.darwin.modules.home = { host, user, ... }: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user.username} = {
      imports =
        [ …input homeModules… (root + "/users/${user.username}") (root + "/hosts/${host.name}/mac.nix") ]
        ++ lib.attrValues config.home.modules            # identity fragments etc.
        ++ map (n: self.homeModules.${n})
             (lib.subtractLists host.excludePrograms (builtins.attrNames self.homeModules));
    };
  };
};
```

Why opt-out rather than opt-in:

- adding `programs/foo/` still gets it everywhere with **zero** edits — the
  property that makes the current auto-discovery pleasant;
- a host that must not have it spends one word (`excludePrograms = [ "comfyui" ]`);
- the alternative (explicit per-host `programs = [ … ]`) is more legible but
  costs one edit per host per new program. Switch to it only if the excluded
  list starts competing with the included list — i.e. when home-manager reaches
  the servers and most programs are wrong for most hosts.

### 5.4 Deploy nodes derived, not duplicated

```nix
# output.nix — no more literals
flake.deploy.nodes = lib.mapAttrs' (name: host: lib.nameValuePair name {
  inherit (host.deploy) hostname sshUser user interactiveSudo;
  profiles.system.path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.${name};
}) (lib.filterAttrs (_: h: h.deploy != null) config.hosts);
```

### 5.5 What the final tree looks like

```text
flake.nix                    # unchanged: inputs + mkFlake + imports
hosts/
  default.nix                # NEW: registry (data only)
  macair/{default.nix,mac.nix,plist-options.nix,snapshots/}
  homelab-{n150,3070}/, linode-us/
modules/
  default.nix                # imports the rest
  hosts.nix                  # NEW: mkDarwin/mkNixos from the registry
  identity.nix  darwin.nix  nixos.nix  nixos-base.nix
programs/
  default.nix                # auto-discovery (unchanged)
  <name>/{default.nix, darwin.nix, linux.nix, profiles/…}
users/napatsc/default.nix
output.nix                   # deploy derived from the registry
```

Adding a machine: one registry entry + one directory. Adding a program: one
directory. That is the whole contract.

---

## 6. "One program, several machines" — four options, pick the cheapest

### 6.1 Inline `mkIf` on the edge (small divergence)

```nix
flake.homeModules.ssh = { lib, pkgs, ... }: {
  config = lib.mkIf pkgs.stdenv.isDarwin {
    programs.ssh.extraOptionOverrides.UseKeychain = "yes";
  };
};
```

Use for 1–5 lines. Do **not** branch on `config.networking.hostName` or
`osConfig` — the first scatters strings, the second forces `osConfig` into every
home-manager evaluation.

### 6.2 Split files inside the program dir (medium divergence)

```text
programs/neovim/
  default.nix     # shared: plugins, extraPackages, editor defaults
  darwin.nix      # clipboard = "pbcopy", guifont, no linux-only LSP
  linux.nix       # wayland clipboard, system python
  profiles/
    minimal.nix   # headless/server: no LSP, no telescope
```

```nix
# programs/neovim/default.nix
flake.homeModules.neovim = { host, lib, ... }: {
  imports = [
    (if host.class == "darwin" then ./darwin.nix else ./linux.nix)
  ] ++ lib.optional (builtins.elem "server" host.tags) ./profiles/minimal.nix;
  programs.neovim.enable = true;
  # shared settings…
};
```

`imports` **can** branch on module arguments (`host` is injected via
`_module.args` in §5.2), because `imports` is evaluated per module instance.
What `imports` cannot do is be wrapped in `lib.mkIf` — that is the single most
common structural surprise; `mkIf` only works on *options*, so branching
configuration must be written as `config = lib.mkIf cond { … };`.

### 6.3 An explicit per-host profile option (large, deliberate divergence)

Declare the axis once, in the program:

```nix
options.my.programs.neovim.profile = lib.mkOption {
  type = lib.types.enum [ "full" "minimal" "off" ];
  default = "full";
};
```

then set it from the host's own file:

```nix
# hosts/homelab-n150/default.nix
{ ... }: { my.programs.neovim.profile = "minimal"; }
```

Best when the difference is a *decision* (this box is a server) rather than an
*incident* (this box has no clipboard). It is also self-documenting:
`grep -r my.programs. hosts/` answers "how do machines differ".

### 6.4 Aspects (only if you need cross-class reuse)

If the same feature must touch NixOS + darwin + home-manager and be included by
several hosts, path-based imports are the wrong tool and `den`'s
`provides`/`includes` is the right one:

```nix
den.aspects.tailscale = {
  nixos.services.tailscale.enable = true;
  homeManager.programs.ssh.settings."*.ts.net".UserKnownHostsFile = "/dev/null";
};
```

Rule of thumb: **three classes × ≥2 consumers** → aspect. Otherwise a plain
module with `mkIf`/`imports` is cheaper to read.

---

## 7. Anti-patterns seen in the wild (and in this repo's future)

- **Host identity by magic string.** `if config.networking.hostName == "macair"`
  sprinkled across modules. One `my.host` / `hostSpec` option, read everywhere.
- **Putting shared values in `specialArgs`.** They are invisible to
  `imports` resolution of sibling modules and can't be `mkDefault`ed. Use a
  module (`_module.args` at the boundary, logged once, or plain options).
  `modules/*.nix` currently passes `user` via `specialArgs`; if you keep it, say
  so in `AGENTS.md` as the *one* documented exception.
- **`lib.mkForce` as a conflict strategy.** Two writers instead of one owner;
  the repo already hit this with `nix/ssh_config.d/100-linux-builder.conf`. Fix
  the ownership, not the priority.
- **`imports` lists that only grow.** At ~10 entries per host, switch to
  directory discovery (`readDir`/`scanPaths`) or `import-tree`.
- **Copy-pasted host directories.** Divergence should be a tag, a profile, or a
  registry field — never a fork of a directory.
- **`system` from the environment.** `builtins.currentSystem`, or `system` read
  inside a module: use `pkgs.stdenv.hostPlatform.system`, or flake-parts'
  `withSystem`/`perSystem`.
- **Deep relative paths** (`../../../../modules/…`). Bind `root = ../.;` once per
  file (this repo's `rootPath`) or expose `lib.custom.relativeToRoot`.
- **Adopting digga.** Deprecated.
- **Eval-time surprises.** `den`/`haumea`-style auto-loading makes "why isn't my
  file imported" a real question; `import-tree` deliberately keeps it to
  `_`-prefix exclusion, which is the least surprising form of magic.

---

## 8. Migration order (each step is independently landable)

1. `hosts/default.nix` — registry, no consumers yet. `nix flake check`.
2. `modules/hosts.nix` — generate both configuration sets from the registry;
   delete the literals from `modules/darwin.nix` / `modules/nixos.nix`.
   Behaviour identical (same three+one hosts, same modules) — verify with
   `nix eval .#darwinConfigurations.macair.config.system.build.toplevel.drvPath`
   before/after.
3. `output.nix` — derive `deploy.nodes`; check
   `nix eval .#deploy.nodes --json` matches the old output.
4. `modules/darwin.nix` — filter `self.homeModules` by
   `host.excludePrograms` (empty at first), inject `_module.args.host`.
5. Optional: move `config.home.modules.git` from `modules/identity.nix` into
   `programs/git/`, keeping `options.user` where it is.
6. Optional, only when #3 in §4 (program selection) becomes painful: adopt
   `import-tree` for `modules/` and `programs/`, deleting both `imports` lists.

---

## 9. Checklist

### Add a host

1. `hosts/<name>/` with `default.nix` (+ `hardware-configuration.nix`, or disko).
2. One entry in `hosts/default.nix`.
3. `git add` both, `nix flake check`, then `darwin-rebuild` / `deploy-rs`.

### Add a program

1. `programs/<name>/default.nix` exporting `flake.homeModules.<name>`.
2. If it must not run somewhere: `excludePrograms = [ "<name>" ];` on that host.
3. If it differs per machine: `darwin.nix`/`linux.nix` + `host.tags`, or a
   `my.programs.<name>.profile` option.

### Add a shared feature

- Common to all → `modules/nixos-base.nix` (nixos), `modules/darwin.nix`
  (darwin), or a `flake.homeModules.*` (user).
- Common to some → tag it (`tags = [ "gui" ]`) and `lib.mkIf`/`optional` on the
  tag; don't fork the host.

---

## 10. References

- Dendritic pattern spec — <https://github.com/mightyiam/dendritic>
- Dendritic pattern, original discourse thread — <https://discourse.nixos.org/t/the-dendritic-pattern/61271>
- Dendritic guide + `_` convention — <https://import-tree.denful.dev/guides/dendritic>
- `import-tree` (auto-import a directory) — <https://github.com/denful/import-tree>
- `den` (aspect-oriented, `provides`/`includes`) — <https://github.com/denful/den>
- flake-parts: module arguments (`withSystem`, `moduleWithSystem`, `perSystem`) — <https://flake.parts/module-arguments>
- flake-parts: built-in options (`flake.*`, `perSystem`) — <https://flake.parts/options/flake-parts.html>
- Misterio77/nix-config + nix-starter-configs — <https://github.com/Misterio77/nix-config>, <https://github.com/Misterio77/nix-starter-configs>
- EmergentMind/nix-config (core/optional + hostSpec) — <https://codeberg.org/EmergentMind/nix-config>
- ryan4yin/nix-config (one file per host, haumea) — <https://github.com/ryan4yin/nix-config>
- drupol/infra (dendritic + den in production) — <https://github.com/drupol/infra>
- nixos-unified — <https://github.com/srid/nixos-unified>
- digga deprecation notice — <https://github.com/divnix/digga>
