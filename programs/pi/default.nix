# pi — AI coding agent for the terminal
{ ... }:
let
  secrets-dir = ../../secrets;

  # Declarative base settings. Kept OUT of `programs.pi-coding-agent.settings`
  # because that option materializes settings.json as a read-only nix-store
  # symlink. We instead write settings.json as a REAL (mutable) file via
  # home.activation.piSettings below — so pi can persist runtime state like
  # `lastChangelogVersion`, while on each rebuild the declarative keys here
  # still get re-applied (a merge keeps any extra keys pi wrote).
  piSettings = {
    defaultProvider = "opencode-go";
    defaultModel = "deepseek-v4.1-flash";
    defaultThinkingLevel = "high";
    theme = "dark";
    packages = [
      "https://github.com/donrami/pi-go-bars"
      "https://github.com/apmantza/pi-lens"
      "npm:@duarteocarmo/pi-jumper"
    ];
  };

  piSettingsJson = builtins.toJSON piSettings;
in
{
  flake.homeModules.pi =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.pi-coding-agent = {
        enable = true;

        extraPackages = with pkgs; [
          agent-browser
          nodejs_latest
        ];

        # Note: `settings` is intentionally NOT set here. The upstream module
        # turns it into a read-only store symlink (~/.pi/agent/settings.json),
        # which would make the file immutable. We manage settings.json as a
        # real file through home.activation.piSettings instead.
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

      # Write settings.json as a MUTABLE real file (not a store symlink).
      # If it already exists, merge: declarative keys are authoritative while
      # extra keys pi writes (e.g. lastChangelogVersion) are preserved, so pi
      # can save runtime state between rebuilds.
      home.activation.piSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        # Note: use HM's built-in `run` here — do NOT redefine it (redefining
        # clobbers the run helper HM uses elsewhere in the activation script).
        run mkdir -p "$HOME/.pi/agent"
        f="$HOME/.pi/agent/settings.json"
        if [ -e "$f" ]; then
          run ${lib.getExe pkgs.jq} -n --argjson d '${piSettingsJson}' --slurpfile e "$f" \
            '($e[0] // {}) * $d' > "$f.new" \
            && run mv -f "$f.new" "$f" \
            || rm -f "$f.new"
        else
          run ${pkgs.coreutils}/bin/printf '%s\n' '${piSettingsJson}' > "$f"
        fi
      '';
    };
}
