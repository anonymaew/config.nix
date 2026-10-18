# yabai — tiling window manager for macOS
# Custom HM module (mirrors nix-darwin's services.yabai)
{ ... }: {
  flake.homeModules.yabai =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    with lib;

    let
      cfg = config.services.yabai;

      toYabaiConfig =
        opts: concatStringsSep "\n" (mapAttrsToList (p: v: "yabai -m config ${p} ${toString v}") opts);

      configFile = pkgs.writeScript "yabairc" (
        (if cfg.config != { } then toYabaiConfig cfg.config else "")
        + optionalString (cfg.extraConfig != "") ("\n" + cfg.extraConfig + "\n")
      );
    in
    {
      options.services.yabai = {
        enable = mkEnableOption "yabai window manager";

        package = mkOption {
          type = types.package;
          default = pkgs.yabai;
          defaultText = literalExpression "pkgs.yabai";
          description = "The yabai package to use.";
        };

        config = mkOption {
          type = types.attrs;
          default = { };
          example = literalExpression ''
            {
              layout             = "bsp";
              window_placement   = "second_child";
              top_padding        = 10;
              bottom_padding     = 10;
              left_padding       = 10;
              right_padding      = 10;
              window_gap         = 10;
              mouse_modifier     = "alt";
              mouse_action1      = "move";
              mouse_action2      = "resize";
              mouse_drop_action  = "swap";
            }
          '';
          description = ''
            Key/Value pairs to pass to yabai's 'config' domain via the
            configuration file. Each key/value becomes
            `yabai -m config <key> <value>`.
          '';
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          example = literalExpression ''
            yabai -m rule --add app='System Preferences' manage=off
          '';
          description = "Extra arbitrary configuration to append to the configuration file.";
        };

        enableScriptingAddition = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to enable yabai's scripting-addition.
            SIP must be disabled for this to work.
          '';
        };
      };

      config = mkIf cfg.enable {
        home.packages = [ cfg.package ];

        launchd.agents.yabai = {
          enable = true;
          config = {
            ProgramArguments = [
              "${cfg.package}/bin/yabai"
            ]
            ++ optionals (cfg.config != { } || cfg.extraConfig != "") [
              "-c"
              configFile
            ];
            KeepAlive = true;
            RunAtLoad = true;
            EnvironmentVariables = {
              PATH = "${cfg.package}/bin:${config.home.profileDirectory}/bin";
            };
          };
        };
      };
    };
}
