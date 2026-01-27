# `config.nix`

My computer/server configuration on Nix language.

```
# nix flake show
├───darwinConfigurations: unknown
├───deploy: unknown
└───nixosConfigurations
    ├───hetzner-sg: NixOS configuration
    └───homelab: NixOS configuration
```

## Deployment

For Mac machine:

```sh
sudo darwin-rebuild switch --flake .
```

For deploying flakes to remote machine:

```sh
# for homelab
nix run github:serokell/deploy-rs -- .#homelab
# for hetzner-sg
nix run github:serokell/deploy-rs -- .#hetzner-sg
```
