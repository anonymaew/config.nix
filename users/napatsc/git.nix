{...}: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Napat Srichan";
        email = "me@napatsc.com";
      };

      # git syntax highlight via delta
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true; # use n and N to move between diff sections
        dark = true; # or light = true, or omit for auto-detection
      };
      merge.conflictStyle = "zdiff3";
    };
    signing = {
      signByDefault = true;
      format = "openpgp";
      key = "74C4 EA31 DDE9 7553 0A15  B036 A46D 60E5 7550 D198";
    };
    lfs.enable = true;
  };
}
