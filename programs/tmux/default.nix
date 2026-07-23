# tmux — terminal multiplexer
{ ... }: {
  flake.homeModules.tmux = { pkgs, ... }:
    let
      sharedConfig = ./tmux.conf;
    in
    {
      programs.tmux = {
        enable = true;
        keyMode = "vi";
        terminal = "xterm-ghostty";
        plugins = [ ];
        baseIndex = 1;
        escapeTime = 10;
        focusEvents = true;
        extraConfig = ''
          set -g status-right '#{user}@#h  %H:%M'
          set -g @nix_tmux 1
          run '${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux'
          run '${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/resurrect.tmux'
          source-file ${sharedConfig}
        '';
      };
    };
}
