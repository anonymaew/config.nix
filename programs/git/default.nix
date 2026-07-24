# git — version control
# Identity (user.name, user.email, signing key) is set by modules/identity.nix
{ ... }: {
  flake.homeModules.git = { pkgs, ... }: {
    home.packages = with pkgs; [ delta ];

    programs.git = {
      enable = true;
      settings = {
        # git syntax highlight via delta
        core.pager = "delta";
        interactive.diffFilter = "delta --color-only";
        delta = {
          navigate = true; # use n and N to move between diff sections
          dark = true; # or light = true, or omit for auto-detection
        };
        merge.conflictStyle = "zdiff3";
      };
      lfs.enable = true;
    };
  };
}
