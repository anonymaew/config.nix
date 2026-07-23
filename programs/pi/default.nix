# pi — AI coding agent for the terminal
{ ... }: {
  flake.homeModules.pi =
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
          shellCommandPrefix = "export SEARXNG_URL='https://search.napatsc.net'";
          packages = [
            "https://github.com/donrami/pi-go-bars"
            "https://github.com/apmantza/pi-lens"
          ];
        };
      };

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

      home.activation.createPiSecretSymlinks = lib.hm.dag.entryAfter [ "writeActivation" ] ''
        mkdir -p ~/.pi/agent
        ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-models ~/.pi/agent/models.json
        ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-auth ~/.pi/agent/auth.json
        ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-go-bars ~/.pi/agent/pi-go-bars.json
      '';
    };
}
