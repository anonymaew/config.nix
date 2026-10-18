# modules — feature modules (each is a flake-parts module)
{ ... }: {
  imports = [
    ./identity.nix
    ./nixos-base.nix
    ./darwin.nix
    ./nixos.nix
  ];
}
