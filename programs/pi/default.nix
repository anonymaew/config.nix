{
  pkgs,
  config,
  lib,
  secrets-dir,
  ...
}:
{
  programs.pi-coding-agent = {
    enable = true;

    extraPackages = with pkgs; [
      agent-browser
      nodejs_latest
    ];

    settings = {
      defaultProvider = "opencode-go";
      defaultModel = "mimo-v2.5";
      defaultThinkingLevel = "high";
      theme = "dark";
      # Inject SEARXNG_URL for search-engine skill (only in pi's shell)
      shellCommandPrefix = "export SEARXNG_URL='https://search.napatsc.net'";
      packages = [
        "https://github.com/donrami/pi-go-bars"
        "https://github.com/apmantza/pi-lens"
      ];
    };

    # models.json is provided via sops-nix (encrypted at rest, decrypted at runtime)
    # No need to set models here - it's symlinked from the sops secret
  };

  # sops secrets for pi (encrypted at rest, decrypted at runtime)
  sops.secrets = {
    pi-models = {
      sopsFile = secrets-dir + "/models.json";
      key = "";
      format = "json";
    };
    pi-auth = {
      sopsFile = secrets-dir + "/auth.json";
      key = "";
      format = "json";
    };
    pi-go-bars = {
      sopsFile = secrets-dir + "/go-bars.json";
      key = "";
      format = "json";
    };
  };

  # These live under configDir (~/.pi/agent), so paths are
  # relative to $HOME: .pi/agent/...
  # sops-nix symlinks decrypted secrets to ~/.config/sops-nix/secrets/<secret-name> at runtime
  # Create symlinks at login time (after sops-nix.service runs)
  home.activation.createPiSecretSymlinks = lib.hm.dag.entryAfter [ "writeActivation" ] ''
    mkdir -p ~/.pi/agent
    ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-models ~/.pi/agent/models.json
    ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-auth ~/.pi/agent/auth.json
    ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-go-bars ~/.pi/agent/pi-go-bars.json
  '';
}
