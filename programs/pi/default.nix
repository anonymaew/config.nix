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

      # agent-desktop (vercel-labs) has no nixpkgs package: upstream ships
      # prebuilt, code-signed Mach-O binaries plus a `macos-helper` that MUST
      # live beside the main executable (it is looked up relative to argv[0]).
      # The binaries are installed verbatim — `dontFixup` keeps nixpkgs from
      # rewriting install names / re-signing, which would invalidate the
      # signature macOS TCC uses for the Accessibility grant.
      #
      # First use needs the Accessibility permission:
      #   agent-desktop permissions --guide
      # TCC keys the grant to the resolved store path, so a version bump asks
      # for the grant again.
      agentDesktop =
        let
          system = pkgs.stdenv.hostPlatform.system;
          target =
            {
              aarch64-darwin = {
                asset = "aarch64-apple-darwin";
                hash = "sha256-IZgTQouxrY3srhcvrtBcWWSiQVFw30AuJ4bM+mRSuoI=";
              };
            }
            .${system} or (throw "agent-desktop: add a release hash for ${system}");
          version = "1.2.0";
        in
        pkgs.stdenv.mkDerivation {
          pname = "agent-desktop";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/vercel-labs/agent-desktop/releases/download/v${version}/agent-desktop-v${version}-${target.asset}.tar.gz";
            hash = target.hash;
          };

          dontUnpack = true;
          dontFixup = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            ${pkgs.gnutar}/bin/tar xzf $src -C $out/bin
            chmod +x $out/bin/agent-desktop $out/bin/agent-desktop-macos-helper
            runHook postInstall
          '';

          meta = {
            description = "Computer use for AI agents via the OS accessibility tree";
            homepage = "https://github.com/vercel-labs/agent-desktop";
            license = pkgs.lib.licenses.asl20;
            mainProgram = "agent-desktop";
          };
        };

      # MCP servers, written to ${piDir}/mcp.json by home.activation.piMcp.
      # `exposure` decides how the model reaches each tool:
      #   direct   — declared like a built-in tool (small, frequently used)
      #   deferred — loaded on demand by `tool_search` (large tool sets)
      # Paths are absolute store paths so the spawn does not depend on the
      # session PATH; mcp.json is regenerated on every activation, so a package
      # bump cannot leave a stale path behind.
      piMcp = {
        mcpServers = {
          agent-browser = {
            command = lib.getExe pkgs.agent-browser;
            args = [ "mcp" ];
            description = "Browser automation over CDP: navigate, snapshot, click, type, scrape pages.";
            exposure = "direct";
          };
          agent-desktop = {
            command = lib.getExe agentDesktop;
            args = [ "mcp" ];
            description = "Operate macOS desktop apps through the accessibility tree (no screenshots).";
            # 60+ tools: keep them behind tool_search instead of inflating the
            # prompt on every turn.
            exposure = "deferred";
            timeout = 120;
          };
          degoog = {
            # Self-hosted degoog (homelab-helm/degoog): the official MCP sidecar
            # is mounted by path on the same host as the UI — the gateway
            # prefers the longest match, so /mcp beats the "/" route.
            url = "https://search.napatsc.net/mcp";
            # Auth is at the edge (agentgateway + Pocket ID), and it accepts
            # JWT access tokens only — the old shared bearer secret was dropped
            # upstream in homelab-helm 3187a55, so there is deliberately no
            # `headers` block here. A header would also disable pi's OAuth flow
            # entirely (OAuth only applies to HTTP servers without one). CIMD
            # lets pi register itself instead of pre-registering a client;
            # tokens land in $PI_CODING_AGENT_DIR/mcp-auth.json.
            # One-time per machine: `pi mcp login degoog` (or /mcp → Sign in).
            oauth.clientRegistration = "cimd";
            description = "Self-hosted degoog web + research search (search, bundle_search, discover).";
            exposure = "direct";
          };
        };
      };

      piMcpJson = builtins.toJSON piMcp;

      # The JSON payload never travels through a shell string. Writing it inline
      # (`printf '%s\n' '<json>'`) breaks as soon as a value contains a single
      # quote: the quote closes bash's single-quoted literal, printf then sees
      # several arguments and repeats its `%s\n` format for each one — which
      # produced an mcp.json with a raw newline inside a JSON string and made pi
      # reject the whole file ("Bad control character in string literal"),
      # silently disabling every MCP server. Payload in the store + `jq -s` is
      # immune to quoting, for settings.json too.
      piMcpFile = pkgs.writeText "pi-mcp.json" piMcpJson;
      piSettingsFile = pkgs.writeText "pi-settings.json" piSettingsJson;
    in
    {
      programs.pi-coding-agent = {
        enable = true;

        # nixpkgs' derivation deletes the @earendil-works/pi-schema workspace
        # while pi-ai/dist/providers/compat-schema.js still imports it, so every
        # child subagent session died with "Cannot find module
        # '@earendil-works/pi-schema'". See pi-schema-fix.nix for the details.
        package = import ./pi-schema-fix.nix { inherit pkgs; };

        extraPackages = with pkgs; [
          agent-browser
          agentDesktop
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
        # NOTE: there is no `degoog-mcp-token` secret any more. /mcp is
        # authenticated at the edge with Pocket ID JWTs (agentgateway), and pi
        # obtains those itself through the CIMD OAuth flow declared above, so a
        # static token would be both dead and harmful (a header disables OAuth).
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
          # Only merge into a file that parses; a corrupt one is replaced instead
          # of being left broken forever (a failed merge used to keep it as-is).
          if [ -e "$f" ] && ${lib.getExe pkgs.jq} -e . "$f" >/dev/null 2>&1; then
            run ${lib.getExe pkgs.jq} -s '(.[0] // {}) * .[1]' "$f" ${piSettingsFile} > "$f.new" \
              && run mv -f "$f.new" "$f" \
              || { rm -f "$f.new"; run ${pkgs.coreutils}/bin/cp ${piSettingsFile} "$f"; }
          else
            run ${pkgs.coreutils}/bin/cp ${piSettingsFile} "$f"
          fi
      '';

      # MCP servers (same mutable-real-file strategy as settings.json):
      # `/mcp` persists exposure/enabled changes and `pi mcp add` appends
      # servers, so a merge keeps those while the declarative entries below
      # stay authoritative.
      #
      # mcpServers is merged SHALLOWLY on purpose. A recursive (`*`) merge can
      # only add or overwrite leaves, so deleting a field from Nix never removes
      # it from the file — that is how a retired `headers.Authorization`
      # survived and kept pi on a dead static token instead of OAuth. With `+`
      # each server this repo declares is replaced as a whole (removals apply),
      # while servers pi added itself, such as `crw`, are left untouched.
      home.activation.piMcp = lib.hm.dag.entryAfter [ "piSettings" ] ''
        run ${pkgs.coreutils}/bin/mkdir -p "${piDir}"
        f="${piDir}/mcp.json"
        if [ -e "$f" ] && ${lib.getExe pkgs.jq} -e . "$f" >/dev/null 2>&1; then
          run ${lib.getExe pkgs.jq} -s '(.[0] // {}) as $cur | (.[1] // {}) as $mine
            | (($cur * ($mine | del(.mcpServers)))
               | .mcpServers = ((($cur.mcpServers) // {}) + ($mine.mcpServers // {})))' \
            "$f" ${piMcpFile} > "$f.new" \
            && run mv -f "$f.new" "$f" \
            || { rm -f "$f.new"; run ${pkgs.coreutils}/bin/cp ${piMcpFile} "$f"; }
        else
          # Missing or unparseable: write the declarative config verbatim.
          if [ -e "$f" ]; then
            echo "pi: ${piDir}/mcp.json was not valid JSON — replaced with the declarative config" >&2
          fi
          run ${pkgs.coreutils}/bin/cp ${piMcpFile} "$f"
        fi
      '';
    };
}
