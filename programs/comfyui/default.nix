# comfyui — node-based diffusion model GUI + API server
#
# `pkgs.comfyui` is the upstream ComfyUI server (not the Electron "Comfy
# Desktop" app) wrapped around a python env whose torch is built with
# `USE_MPS = true` on darwin, so generation runs on the Apple-silicon GPU via
# Metal. It is patched upstream (`use-writable-runtime-paths.patch`) so that
# `--base-directory` defaults to `$XDG_DATA_HOME/comfyui` (falling back to
# `~/.local/share/comfyui`): models/, custom_nodes/, input/, output/ and user/
# therefore live in the home directory and survive rebuilds, while the code
# itself stays read-only in the store.
#
# Two ways to run it:
#   comfyui-serve                  # foreground server -> http://127.0.0.1:8188
#   comfyui                        # raw CLI (`comfyui --help` for all flags)
# Nothing is auto-started: no launchd agent, no login item. Run the server
# from a terminal (or tmux) when you want it and Ctrl-C to stop it.
#
# Caveat: custom nodes that `pip install` new dependencies into the python
# env cannot work here — the env is a store path. Nodes that only import
# packages already present (or ship pure-python) install fine via
# ComfyUI-Manager or by dropping them in custom_nodes/.
#
# MLX (`services.comfyui.enableMlx`): mflux in ComfyUI's env, since a store
# path cannot be pip-installed into. Also puts the `mflux-*` CLIs on PATH.
# Node must be cloned by hand into custom_nodes/ (Manager's pip step fails):
#   ComfyUI-mflux-AnyModel — no FLUX 3 support; use `mflux-generate-flux3`.
# Never add `--lowvram` here: unified memory, offloading only hurts.
{ ... }:
{
  flake.homeModules.comfyui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.comfyui;

      # Writable runtime state. Kept in the same place the upstream patch
      # picks by default, so plain `comfyui` and the wrapper share models.
      dataDir = "${config.home.homeDirectory}/.local/share/comfyui";

      # ── MLX / mflux ───────────────────────────────────────────────
      # nixpkgs pins mflux 0.15.4; 0.24.0 is what supports Qwen-Image 2.1 and
      # FLUX 3. Re-pin locally instead of a global overlay.
      mfluxVersion = "0.24.0";

      pythonMlx = pkgs.python3.override {
        packageOverrides = pyFinal: pyPrev: {
          mflux = pyPrev.mflux.overridePythonAttrs (old: {
            version = mfluxVersion;
            src = pkgs.fetchFromGitHub {
              owner = "mflux-community";
              repo = "mflux";
              tag = "v.${mfluxVersion}";
              hash = "sha256-S4JjxJSHxebSku8ppxxgWWR6gOkzUN8NoTT5/Mh+Djw=";
            };
            postPatch = ""; # old patch targets the dropped uv_build pin
            pythonRelaxDeps = [ # nixpkgs floors: pillow 12.3 vs 13, urllib3 2.7 vs 2.8
              "pillow"
              "huggingface-hub"
              "mlx"
              "urllib3"
            ];
            dependencies = old.dependencies ++ [
              pyFinal.hf-transfer
              pyFinal.protobuf
              pyFinal.pyyaml
            ];
            doCheck = false; # needs network + image generation
          });
        };
      };

      # mflux importable from ComfyUI's own env (needed by the MLX node).
      comfyuiPackage =
        if cfg.enableMlx then
          cfg.package.override {
            python3 = pythonMlx;
            extraPackages = ps: [ ps.mflux ];
          }
        else
          cfg.package;

      serveArgs = [
        "--listen"
        cfg.host
        "--port"
        (toString cfg.port)
        "--preview-method"
        "auto"
        "--base-directory"
        cfg.dataDir
      ]
      ++ cfg.extraArgs;

      # Single definition of the server invocation used by `comfyui-serve`.
      # The directory tree is created here so the very first run works even on a
      # host that never ran an activation step with this module enabled.
      serve = pkgs.writeShellApplication {
        name = "comfyui-serve";
        text = ''
          for d in models/checkpoints custom_nodes input output user; do
            mkdir -p ${lib.escapeShellArg cfg.dataDir}/"$d"
          done
          exec ${lib.getExe comfyuiPackage} ${lib.escapeShellArgs serveArgs} "$@"
        '';
      };
    in
    {
      options.services.comfyui = {
        enable = lib.mkEnableOption "ComfyUI diffusion GUI/API server";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.comfyui;
          defaultText = lib.literalExpression "pkgs.comfyui";
          description = "The ComfyUI package to use.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = ''
            Address to bind. Loopback only by default: the API has no
            authentication, so exposing it needs an explicit opt-in.
          '';
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 8188;
          description = "Port to serve on.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = dataDir;
          defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.local/share/comfyui"'';
          description = ''
            ComfyUI base directory (models, custom_nodes, input, output, user).
            Must stay outside the nix store — it is written to at runtime.
          '';
        };

        enableMlx = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Put MLX (`mflux`) in ComfyUI's env and on PATH — the declarative
            stand-in for `pip install mflux`, which a store path cannot take.
            Larger ComfyUI closure; re-pins mflux to 0.24.0 locally.
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          # No `--lowvram` in the example: unified memory, it only hurts.
          example = [ "--preview-method" "auto" ];
          description = "Extra arguments appended to the ComfyUI command line.";
        };
      };

      config = lib.mkMerge [
        # Program modules in this repo enable themselves; opt out per host with
        # `services.comfyui.enable = false;`.
        { services.comfyui.enable = lib.mkDefault true; }

        (lib.mkIf cfg.enable {
          home.packages = [
            comfyuiPackage
            serve
          ]
          ++ lib.optional cfg.enableMlx pythonMlx.pkgs.mflux;
        })
      ];
    };
}
