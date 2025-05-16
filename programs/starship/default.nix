{
  pkgs,
  lib,
  ...
}: {
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "$shlvl"
        "$shell"
        "$env_var"
        "$username"
        "[@](green)"
        "$hostname"
        ":"
        "$directory"
        "$git_branch"
        "$git_status"
        "$fill"
        "$all"
        "$status"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      continuation_prompt = "[>](grey)";

      character = {
        format = "$symbol ";
        success_symbol = "[\\$](bold green)";
        error_symbol = "[\\$](bold red)";
      };

      # vim subshell
      env_var.VIMSHELL = {
        format = "[$env_value]($style)";
        style = "green italic";
      };

      username = {
        disabled = false;
        show_always = true;
        style_user = "bold green";
        style_root = "bold yellow";
        format = "[$user]($style)";
      };

      hostname = {
        disabled = false;
        ssh_only = false;
        style = "bold green";
        format = "[$hostname]($style)";
      };

      directory = {
        disabled = false;
        truncate_to_repo = false;
        truncation_length = 0;
        style = "blue";
        format = "[$path]($style)[$read_only]($read_only_style)";
      };

      fill = {
        disabled = false;
        style = "white";
      };

      cmd_duration = {
        format = "[$duration](yellow) ";
      };

      git_branch = {
        format = " [$symbol $branch]($style)";
        symbol = "";
        style = "bold yellow";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style))";
        style = "yellow";
      };

      status = {
        disabled = false;
        format = "[$status]($style) ";
      };

      direnv = {
        disabled = false;
        format = "[$symbol$loaded$allowed]($style) ";
        symbol = "󱁿";
        allowed_msg = "";
        not_allowed_msg = "!";
        loaded_msg = "";
        unloaded_msg = "?";
      };

      nix_shell = {
        # disabled = true;
        format = "[$symbol]($style) ";
        symbol = "";
      };
      python = {
        symbol = "🐍";
        format = "[$symbol(\($virtualenv\))]($style) ";
      };

      gcloud.disabled = true;

      bun.format = "[$symbol]($style) ";
      buf.format = "[$symbol]($style) ";
      cmake.format = "[$symbol]($style) ";
      cobol.format = "[$symbol]($style) ";
      crystal.format = "[$symbol]($style) ";
      daml.format = "[$symbol]($style) ";
      dart.format = "[$symbol]($style) ";
      deno.format = "[$symbol]($style) ";
      dotnet.format = "symbol(🎯 $tfm )]($style) ";
      elixir.format = "[$symbol]($style) ";
      elm.format = "[$symbol]($style) ";
      erlang.format = "[$symbol]($style) ";
      fennel.format = "[$symbol]($style) ";
      gleam.format = "[$symbol]($style) ";
      golang.format = "[$symbol]($style) ";
      gradle.format = "[$symbol]($style) ";
      haxe.format = "[$symbol]($style) ";
      helm.format = "[$symbol]($style) ";
      java.format = "[$symbol]($style) ";
      julia.format = "[$symbol]($style) ";
      kotlin.format = "[$symbol]($style) ";
      lua.format = "[$symbol]($style) ";
      meson.format = "[$symbol]($style) ";
      nim.format = "[$symbol]($style) ";
      nodejs.format = "[$symbol]($style) ";
      ocaml.format = "[$symbol(\($switch_indicator$switch_name\) )]($style) ";
      opa.format = "[$symbol]($style) ";
      perl.format = "[$symbol]($style) ";
      pixi.format = "[$symbol($environment )]($style) ";
      php.format = "[$symbol]($style) ";
      pulumi.format = "[$symbol$stack]($style) ";
      purescript.format = "[$symbol]($style) ";
      quarto.format = "[$symbol]($style) ";
      raku.format = "[$symbol]($style) ";
      red.format = "[$symbol]($style) ";
      rlang.format = "[$symbol]($style) ";
      ruby.format = "[$symbol]($style) ";
      rust.format = "[$symbol]($style) ";
      solidity.format = "[$symbol]($style) ";
      typst.format = "[$symbol]($style) ";
      swift.format = "[$symbol]($style) ";
      vagrant.format = "[$symbol]($style) ";
      vlang.format = "[$symbol]($style) ";
      zig.format = "[$symbol]($style) ";
    };
  };
}
