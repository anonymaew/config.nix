# Auto-discover all program modules in this directory.
# Each program directory must have a default.nix that exports flake.homeModules.<name>.
# The 'skills' directory is excluded (has its own flake.nix, consumed as agent-skills input).
{ lib, ... }:
let
  programsDir = ./.;

  # Get all entries in the programs directory
  entries = builtins.readDir programsDir;

  # Filter to directories that have a default.nix
  programDirs = lib.filterAttrs (
    name: type:
    type == "directory"
    && name != "skills" # excluded — consumed as flake input
    && builtins.pathExists (programsDir + "/${name}/default.nix")
  ) entries;

  # Build list of import paths
  imports = lib.mapAttrsToList (name: _: programsDir + "/${name}") programDirs;
in
{
  imports = imports;
}
