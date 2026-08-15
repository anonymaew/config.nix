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

## Install on darwin from scratch

1. install determinate-nix
2. change hostname
3. install xcode (getting git)
4. disable nix-rosetta, and do darwin-switch as from nix run ...
5. TODO: steps on bootstrap nix-rosetta within determinate-nix
6. uninstall xcode

## Migration checklist

- **Important**: secret keys
    - [ ] sops keys in `~/.config/sops`
    - [ ] GPG keys (export as ascii and reimport)
    - [ ] SSH key `~/.ssh/`
    - [ ] kube config `~/.kube`
- **Data**
    - [ ] Zen history/sessions/cookies
    - [ ] pi-coding-agent sessions at `~/.pi/agent/sessions`
    - [ ] tmux (resurrect) sessions at `~/.local/share/tmux/resurrect/last`

