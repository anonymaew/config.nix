{ pkgs, vars, ... }:
{
  programs.tmux =
    {
      enable = true;
      keyMode = "vi";
      terminal = "xterm-256color";
      plugins = with pkgs.tmuxPlugins; [
        tmux-fzf
        {
          # TODO: upgrade to 0.4
          plugin = catppuccin;
          extraConfig = ''
            set -g @catppuccin_flavour "mocha"
            set -g @catppuccin_window_status_style "rounded"
            set -g status-left ""
            set -g status-right "#{E:@catppuccin_status_session}"
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '10'
          '';
        }
        {
          plugin = resurrect;
          extraConfig = ''
              set -g @resurrect-processes 'ssh psql mysql sqlite3'
              set -g @resurrect-strategy-nvim 'session'
              resurrect_dir=~/.local/share/tmux/resurrect
              set -g @resurrect-dir $resurrect_dir
              set -g @resurrect-hook-post-save-all "sed -i 's| --cmd .*-vim-pack-dir||g; s|/etc/profiles/per-user/$USER/bin/||g; s|/nix/store/.*/bin/||g' $(readlink -f $resurrect_dir/last)"
            '';
        }
        vim-tmux-navigator
      ];
      baseIndex = 1;
      extraConfig = ''
        set -g status-position top
        set -g renumber-windows on
        set -g set-clipboard on

        bind-key -T copy-mode-vi 'v' send -X begin-selection
        bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel
        bind  c  new-window      -c "#{pane_current_path}"
        bind  %  split-window -h -c "#{pane_current_path}"
        bind '"' split-window -v -c "#{pane_current_path}"

        # temp fix for tmux-sensible bug, revise later
        # set -gu default-command
        # set -g default-shell "$SHELL"
      '';
    };
}
