# gnupg — GPG encryption
{ ... }: {
  flake.homeModules.gnupg = { config, ... }: {
    programs.gpg = {
      enable = true;
      homedir = "${config.xdg.dataHome}/gnupg";
    };
  };
}
