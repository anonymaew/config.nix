{
  pkgs,
  vars,
  lib,
  brew-nix,
  ...
}:
{
  users.users.${vars.name} = {
    name = "${vars.name}";
    home = "/Users/${vars.name}";
    shell = pkgs.zsh;
  };

  brew-nix.enable = true;
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
      use-xdg-base-directories = true;
      secret-key-files = [ "/etc/nix/nix-secret-key" ];
    };
    gc = {
      automatic = true;
      options = "--delete-generations +8";
    };
    optimise.automatic = true;
    settings.auto-optimise-store = true;
  };
}
