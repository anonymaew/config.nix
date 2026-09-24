# Aerospace — tiling window manager (config + launchd)
# Plus aerospace-swipe: trackpad swipe gestures for workspace switching.
{ inputs, ... }:
let
  aerospace-swipe-src = inputs.aerospace-swipe;
in
{
  flake.homeModules.aerospace =
    { pkgs, ... }:
    let
      aerospaceSwipe = pkgs.callPackage ./aerospace-swipe.nix { src = aerospace-swipe-src; };
    in
    {
      programs.aerospace = {
        enable = true;
        package = pkgs.aerospace;
      };

      xdg.configFile."aerospace/aerospace.toml".source = ./aerospace.toml;

      # ── aerospace-swipe — trackpad gestures ────────────────────────────
      home.packages = [ aerospaceSwipe ];

      # Mirrors ~/.config/aerospace-swipe/config.json
      xdg.configFile."aerospace-swipe/config.json".text = builtins.toJSON {
        haptic = false;
        natural_swipe = true;
        wrap_around = false;
        skip_empty = false;
        fingers = 4;
      };

      launchd.agents.aerospace-swipe = {
        enable = true;
        # gui (Aqua session) — needed for CGEventTap/accessibility
        domain = "gui";
        config = {
          # Run the .app bundle so macOS shows the proper name in
          # System Settings → Privacy & Security → Accessibility
          ProgramArguments = [
            "${aerospaceSwipe}/Applications/AerospaceSwipe.app/Contents/MacOS/AerospaceSwipe"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          LimitLoadToSessionType = "Aqua";
          ProcessType = "Interactive";
          Nice = 0;
          StandardOutPath = "/tmp/swipe.out";
          StandardErrorPath = "/tmp/swipe.err";
        };
      };
    };
}
