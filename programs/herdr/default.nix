# herdr — desktop app for terminals and coding agents, plus its runtime
#
# herdr-app is the window (spaces, tabs, panes); herdr-core provides `hc`, the
# background server that owns every terminal and keeps it running when the
# window closes.
#
# The app comes from the Homebrew cask, the same way programs/ghostty gets its
# app: brew-nix resolves the cask to upstream's signed Herdr.app. The signature
# is not cosmetic here — macOS keys Herdr's privacy prompts (mic, camera,
# AppleScript) to the bundle's signing identity.
#
# The runtime comes from nixpkgs. Upstream ships no cask or formula for it
# (brew-api carries casks only), and nixpkgs builds it from source at 0.1.15 —
# the same version as the cask app — already cached for aarch64-darwin, so it
# installs as a 2.5 MiB fetch rather than a Rust + Zig compile.
#
# Do not switch the app to nixpkgs' `herdr-desktop`: it is 0.1.10, and that
# derivation is uncached on aarch64-darwin (it would compile Rust + Zig
# locally, and its Zig deps need `--option sandbox false` on a cache miss).
#
# herdr-app finds its core on PATH, then the login shell's PATH, then
# ~/.local/bin, then ~/.nix-profile/bin — so the herdr-core installed here is
# picked up with no herdr config at all. Note that ~/.local/bin is searched
# BEFORE the Nix profile: a core left behind by upstream's `curl | sh`
# installer wins until it is deleted.
{ ... }: {
  flake.homeModules.herdr = { pkgs, ... }: {
    home.packages = [
      pkgs.brewCasks.herdr-app
      pkgs.herdr-core
    ];

    # Editor restore helper: the zsh hook in programs/shell/default.nix runs it
    # in every restored herdr shell, and it re-opens nvim where it was. The
    # label it reads is written by programs/neovim/herdr-sessions.lua.
    home.file.".local/libexec/herdr/nvim-resume.py" = {
      source = ./nvim-resume.py;
      executable = true;
    };

    # Start the window at login, through a login shell.
    #
    # Two problems in one job. (1) The app ships no LaunchAgent, so after a
    # reboot nothing runs until herdr is typed by hand. (2) launchd's own
    # environment has no TERMINFO_DIRS: the session-vars agent below skips
    # every value containing "$", and HM's TERMINFO_DIRS is
    # "/etc/profiles/...:$TERMINFO_DIRS${TERMINFO_DIRS:+:}...". Without it
    # herdr's terminals cannot resolve xterm-ghostty, the HM set-environment
    # script bails out, and the shell silently loses the session PATH —
    # verified: `rg` and `gh` unresolved inside a herdr terminal while a tmux
    # shell finds them. `zsh -lc` sources .zshenv, so the app (and the
    # herdr-core it spawns) inherits the full session environment instead.
    launchd.agents.herdr-app = {
      enable = true;
      config = {
        Label = "dev.herdr.app";
        ProgramArguments = [
          "/bin/zsh"
          "-lc"
          "exec ${pkgs.brewCasks.herdr-app}/Applications/Herdr.app/Contents/MacOS/Herdr"
        ];
        RunAtLoad = true;
        KeepAlive = false;
        # launchd needs the parent directory to exist; /tmp always does.
        StandardOutPath = "/tmp/herdr-app.launchd.out";
        StandardErrorPath = "/tmp/herdr-app.launchd.err";
        # Apple's default soft cap is 256 fds (hard is unlimited). herdr-core
        # holds a PTY plus pipes per terminal, so a workspace of ~100 terminals
        # hits EMFILE and `terminal.run` fails with "Too many open files" —
        # which is what stopped the 2026-11-17 tmux migration at 82 terminals.
        # The whole session (core included) inherits this.
        SoftResourceLimits = { NumberOfFiles = 8192; };
        HardResourceLimits = { NumberOfFiles = 8192; };
      };
    };
  };
}
