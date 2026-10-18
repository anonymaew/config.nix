# modules — feature modules (each is a flake-parts module)
{ ... }: {
  imports = [
    ./identity.nix
    ./darwin.nix
    ./nixos.nix
  ];
}
