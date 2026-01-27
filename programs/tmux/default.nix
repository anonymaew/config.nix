{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
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
          resurrect_dir=$XDG_DATA_HOME/tmux/resurrect
          set -g @resurrect-processes 'btop k9s lazygit ssh'
          set -g @resurrect-dir $resurrect_dir
          set -g @resurrect-strategy-vim 'session'
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-hook-post-save-all "sed -i 's| --cmd .*-vim-pack-dir||g; s|/etc/profiles/per-user/$USER/bin/||g; s|/nix/store/.*/bin/||g' $(readlink -f $resurrect_dir/last)"
        '';
      }
    ];
    baseIndex = 1;
    escapeTime = 10;
    focusEvents = true;
    extraConfig = ''
      set -g status-position top
      set -g status-justify absolute-centre
      set -g renumber-windows on
      set -g set-clipboard on

      set -g status-style 'bg=default'
      setw -g window-status-style 'fg=color7'
      setw -g window-status-format ' #I:#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{?#{==:#{pane_current_command},nvim},#{s|n?vim .*\/||:#{pane_title}},#{pane_current_command}}} '
      setw -g window-status-current-style 'fg=default bold'
      setw -g window-status-current-format '[#I:#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{?#{==:#{pane_current_command},nvim},#{s|n?vim .*\/||:#{pane_title}},#{pane_current_command}}}]'

      set -g status-left '#S'
      set -g status-right '#{user}@#h  %H:%M'

      bind-key -T copy-mode-vi 'v' send -X begin-selection
      bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel

      bind '"' split-window -v -c "#{pane_current_path}"
      bind %   split-window -h -c "#{pane_current_path}"
      bind c   new-window   -c    "#{pane_current_path}"
    '';
  };
}
