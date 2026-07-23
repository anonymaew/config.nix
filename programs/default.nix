# Auto-discovery of program modules.
#
# Each program is a flake-parts module that exports:
#   - flake.homeManagerModules.<name>  — Home Manager module
#   - flake.nixosModules.<name>        — NixOS/darwin module
#
# As each program is migrated to the flake-parts module format (Phase 2),
# add its directory to the imports list below to auto-register it.
#
# The skills directory is excluded because it has its own flake.nix and is
# consumed as a separate flake input (agent-skills).
{ ... }: {
  imports = [
    # Phase 2: Add converted programs here, e.g.:
    # ./tmux
    # ./ghostty
    # ./starship
    # ./direnv
    # ./neovim
    # ./k9s
    # ./pi
    # ./taskwarrior
    # ./gnupg
    # ./aerospace
    # ./alacritty
    # ./sketchybar
    # ./skhd
    # ./yabai
    # ./pass
  ];
}
