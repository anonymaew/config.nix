# The bare options attrset that `nix-plist-manager`'s `--against` expects.
#
# `--against <file>` does `import <file>` and looks option paths up from the
# root (`applications.systemSettings…`), so it cannot read `mac.nix` directly:
# that file is a home-manager module, where the same tree sits under
# `programs.nix-plist-manager.options`. Handing it the module makes every lookup
# miss and the tool report all ~126 readable settings as differing.
#
#   nix run github:SushyDev/nix-plist-manager/v3.0.0#current -- \
#     --scope user --against hosts/macair/plist-options.nix
#
(import ./mac.nix).programs.nix-plist-manager.options
