# pi — AI coding agent for the terminal
{ ... }:
let
  # Per-host secrets layout (see .sops.yaml): macair's credentials live under
  # secrets/hosts/macair/, encrypted to the admin age key only.
  secrets-dir = ../../secrets/hosts/macair;

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
      # "npm:pi-subagents-lite"
      "npm:pi-subagents"
      # Restores the exact pi session per tmux pane via tmux-resurrect.
      # tmux.conf has the matching @resurrect-hook-post-save-layout.
      "https://github.com/fabiangigler/pi-tmux-session-tracker"
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
    let
      # pi defaults to ~/.pi/agent for EVERYTHING: settings, auth, sessions,
      # installed packages and git checkouts. PI_CODING_AGENT_DIR is the
      # documented override (docs/environment-variables.md). Every path below
      # must derive from this binding — a literal ~/.pi/agent anywhere in the
      # activations silently defeats the move.
      # NOTE: keep the segment `pi/agent` — writing `${xdg.dataHome}/.pi/agent`
      # yields a hidden ~/.local/share/.pi/agent and pi then starts fresh there.
      piDir = "${config.xdg.dataHome}/pi/agent";
    in
    {
      programs.pi-coding-agent = {
        enable = true;

        extraPackages = with pkgs; [
          agent-browser
          nodejs_latest
          # Nix language server + formatter for pi-lens. pi-lens has exactly one
          # nix runner (the `nixd` LSP, clients/lsp/server.ts) and never
          # auto-installs it, so without this every .nix check silently reports
          # "clean". nixfmt matches the flake formatter in output.nix.
          nixd
          nixfmt
        ];

        # Note: `settings` is intentionally NOT set here. The upstream module
        # turns it into a read-only store symlink ($piDir/settings.json),
        # which would make the file immutable. We manage settings.json as a
        # real file through home.activation.piSettings instead.
      };

      home.sessionVariables = {
        PI_CODING_AGENT_DIR = piDir;
        # pi-lens otherwise owns a 1.1 GB ~/.pi-lens (vendored LSP binaries +
        # per-project caches). Documented override: clients/config-resolve.ts
        # reads PI_LENS_HOME for getGlobalPiLensDir().
        PI_LENS_HOME = "${config.xdg.dataHome}/pi-lens";
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
        mkdir -p ${piDir}
        ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-models ${piDir}/models.json
        ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-auth ${piDir}/auth.json
        ${pkgs.coreutils}/bin/ln -sf ${config.xdg.configHome}/sops-nix/secrets/pi-go-bars ${piDir}/pi-go-bars.json
      '';

      # Write settings.json as a MUTABLE real file (not a store symlink).
      # If it already exists, merge: declarative keys are authoritative while
      # extra keys pi writes (e.g. lastChangelogVersion) are preserved, so pi
      # can save runtime state between rebuilds.
      home.activation.piSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        # Note: use HM's built-in `run` here — do NOT redefine it (redefining
        # clobbers the run helper HM uses elsewhere in the activation script).
        run mkdir -p "${piDir}"
        f="${piDir}/settings.json"
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
