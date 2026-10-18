# pass — password store
{ ... }: {
  flake.homeModules.pass = { ... }: {
    programs.password-store = {
      enable = true;
    };
  };
}
