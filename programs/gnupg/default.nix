# gnupg — GPG encryption, plus the agent that serves its passphrases
{ ... }: {
  flake.homeModules.gnupg = { config, pkgs, ... }: {
    programs.gpg = {
      enable = true;
      homedir = "${config.xdg.dataHome}/gnupg";
    };

    # `programs.gpg` writes only `gpg.conf`. The agent needs its own config: with
    # no `pinentry-program` it falls back to searching PATH for a bare
    # `pinentry`, which this system does not have, so any signature that needs a
    # passphrase fails with "No pinentry". It stays invisible while the
    # passphrase is cached, which is what made it look intermittent.
    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry_mac;
      # Upstream defaults are 10 min idle / 2 h absolute, short enough that a
      # signing session spanning a coffee break starts prompting again.
      defaultCacheTtl = 28800;
      maxCacheTtl = 86400;
    };
  };
}
