{pkgs, ...}: {
  imports = [
    ./git.nix
  ];

  # programs.neomutt.enable = true;
  # programs.notmuch.enable = true;
  # programs.mbsync = {
  #   enable = true;
  #   package = pkgs.writeShellScriptBin "mbsync" ''
  #     ${pkgs.isync}/bin/mbsync $@
  #     notmuch new
  #   '';
  # };
  #
  # accounts.email.accounts = {
  #   personal = {
  #     address = "napatsrichan2001@gmail.com";
  #     userName = "napatsrichan2001@gmail.com";
  #     primary = true;
  #     imap = {
  #       host = "imap.gmail.com";
  #     };
  #
  #     mbsync = {
  #       enable = true;
  #       create = "maildir";
  #     };
  #     notmuch.enable = true;
  #     neomutt.enable = true;
  #   };
  # };
}
