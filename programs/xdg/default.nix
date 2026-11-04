# xdg — the $HOME paths that tools put there anyway
#
# Most of them are redirected with an env var in programs/shell/default.nix
# (NPM_CONFIG_CACHE, KUBECACHEDIR, MPLCONFIGDIR, KUBECONFIG, …). This module is
# for the leftovers: tools whose path is a literal in their own source and that
# are writable, so a source patch can teach them an env var. The patch is
# re-applied on every switch because an upgrade rewrites the package.
#
#   camoufox-cli (uv tool)   ~/.camoufox-cli/{profiles,config.json}
#                            → $CAMOUFOX_CLI_HOME, set below and consumed by
#                              patch-camoufox.py
#
# Stays in $HOME on purpose:
#   ~/.agent-browser    the CLI is a nix store binary, and no knob moves the
#                       state dir: `AGENT_BROWSER_CONFIG` with stateDir/socketDir
#                       still reports ~/.agent-browser in `doctor`, and the
#                       AGENT_BROWSER_*DIR vars only cover screenshots/sockets.
#                       A symlink shim into ~/.local/share was tried and dropped
#                       — not worth the indirection for the one directory no
#                       dotfile tool reads.
#   ~/.ssh              OpenSSH has no XDG support and the keys must stay.
#   ~/.agents           home-manager owns that symlink (programs/skills).
#   ~/.mnt              SMB mountpoints, chosen on purpose over an XDG dir.
#   ~/.nix-profile, ~/.nix-defexpr
#                       nix's own symlinks; `use-xdg-base-directories` in
#                       nix.conf is the only supported way to relocate them.
{ ... }: {
  flake.homeModules.xdg =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.sessionVariables = {
        # read by programs/xdg/patch-camoufox.py
        CAMOUFOX_CLI_HOME = "${config.xdg.dataHome}/camoufox-cli";
      };

      # camoufox-cli hardcodes ~/.camoufox-cli in its own Python source; the
      # patch adds a CAMOUFOX_CLI_HOME fallback, and this re-applies it because
      # `uv tool upgrade` rewrites site-packages.
      home.activation.xdgCamoufoxPatch = lib.hm.dag.entryAfter [ "writeActivation" ] ''
        run ${pkgs.python3}/bin/python3 ${./patch-camoufox.py} "$HOME"
      '';
    };
}
