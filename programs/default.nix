# Auto-discovery of program modules for flake-parts.
#
# This file defines flake.homeManagerModules — a set of Home Manager modules
# for each program. Adding a converted program here makes it available via
# `self.homeManagerModules.<name>` in other parts of the config.
#
# Each program directory contains a plain Home Manager module (not a flake-parts
# module) in its default.nix. We aggregate them here into a single flake output.
#
# The skills directory is excluded because it has its own flake.nix and is
# consumed as a separate flake input (agent-skills).
#
# Phase 2 migration: as each program is converted, it's added here and
# removed from home.nix's direct imports.
{ inputs, ... }: {
  flake.homeManagerModules = {
    # ── Terminal programs ──
    tmux    = import ./tmux;
    ghostty = import ./ghostty;
    starship = import ./starship;

    # ── Dev tools ──
    direnv    = import ./direnv;
    neovim    = import ./neovim;
    k9s        = import ./k9s;
    pi         = import ./pi;
    taskwarrior = import ./taskwarrior;
    gnupg      = import ./gnupg;

    # ── Desktop programs ──
    aerospace  = import ./aerospace;
    alacritty  = import ./alacritty;
    sketchybar = import ./sketchybar;
    skhd       = import ./skhd;
    yabai      = import ./yabai;
    pass       = import ./pass;
  };
}
