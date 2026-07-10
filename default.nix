{
  pkgs,
  vars,
  lib,
  brew-nix,
  ...
}: {
  imports = import ./programs/darwin-default.nix;
  users.users.${vars.name} = {
    name = "${vars.name}";
    home = "/Users/${vars.name}";
    shell = pkgs.zsh;
  };

  brew-nix.enable = true;
  nixpkgs.config = {
    allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "steam-unwrapped"
        "zoom"
      ];
  };
  nixpkgs.overlays = import ./overlays ++ [brew-nix.overlays.default];

  # services.nix-daemon.enable = true;
  nix = {
    settings = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
      use-xdg-base-directories = true;
    };
    gc = {
      automatic = true;
      options = "--delete-generations +8";
    };
    optimise.automatic = true;
    settings.auto-optimise-store = true;
  };

  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts
  ];
}
