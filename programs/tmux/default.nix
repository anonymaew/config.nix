{ pkgs, ... }:
let
  # Same tmux.conf used on both Nix and non-Nix:
  # - On Nix: loaded via extraConfig (sets @nix_tmux, then source-file)
  # - On non-Nix: copy to ~/.config/tmux/tmux.conf (XDG); TPM handles plugins
  sharedConfig = ./tmux.conf;
in
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    terminal = "xterm-ghostty";
    # Plugins managed manually below so we can set status-right first
    # (continuum needs to prepend its save script to our status-right format).
    plugins = [ ];
    baseIndex = 1;
    escapeTime = 10;
    focusEvents = true;
    extraConfig = ''
      # ── custom status-right (set before plugins so continuum can prepend) ──
      set -g status-right '#{user}@#h  %H:%M'

      # ── Nix sentinel (tells tmux.conf to skip TPM) ──
      set -g @nix_tmux 1

      # ── manually load plugins (order matters: status-right must be set first) ──
      run '${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux'
      run '${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/resurrect.tmux'

      # ── shared config (general settings, no status-right override) ──
      source-file ${sharedConfig}
    '';
  };
}
