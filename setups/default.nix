# Setup compositions.
#
# A "setup" is a collection of programs for a specific use case.
# Hosts select which setup(s) to use rather than wiring programs directly.
#
# Each setup exports flake.nixosModules.<name> and/or
# flake.homeManagerModules.<name> for use in host configs.
#
# Populated in Phase 3 of the migration plan.
{ ... }: {
  imports = [
    ./desktop
    ./dev
    ./kubernetes
    ./self-hosted
    ./server
  ];
}
