# Import index — each program directory is its own flake-parts module.
# The skills directory is excluded (has its own flake.nix, consumed as agent-skills input).
{ ... }: {
  imports = [
    ./tmux
    ./ghostty
    ./starship
    ./direnv
    ./neovim
    ./k9s
    ./pi
    ./taskwarrior
    ./gnupg
    ./aerospace
    # ./sketchybar  # deactivated
    ./skhd
    ./yabai
    ./pass
    ./git
    ./shell
    ./skills
  ];
}
