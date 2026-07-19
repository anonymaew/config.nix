# Secrets Management with sops-nix

## Age-based Setup

- **Admin age key** — for editing secrets on Mac
- **Machine age keys** — derived from SSH host keys (homelab, hetzner)

## Directory Structure

```
secrets/
├── homelab.yaml     # k3s token, wireguard client config
├── hetzner.yaml     # wireguard server private key
├── darwin.json      # model provider API key
├── auth.json        # opencode API keys (whole-file)
├── go-bars.json     # pi workspace/cookie (whole-file)
└── README.md
```

## Editing Secrets

```bash
# YAML files (homelab, hetzner)
sops secrets/homelab.yaml

# JSON files (darwin, auth, go-bars)
sops secrets/darwin.json
sops secrets/auth.json
sops secrets/go-bars.json
```

## How It Works

### NixOS (homelab, hetzner)

- sops-nix decrypts secrets at boot using SSH host age keys
- Secrets available at `config.sops.secrets.<name>.path`
- Used for: k3s token, wireguard private keys

### macOS (macair)

- sops-nix decrypts secrets via launchd agent at login
- Secrets symlinked to `~/.config/sops-nix/secrets/<name>`
- Pi program symlinks secrets to `~/.config/pi/`

### Whole-file encryption

- `key = ""` means the entire file content is the secret
- Used for `auth.json` and `go-bars.json`

## Adding New Secrets

1. Open with `sops secrets/<file>.json`
2. Add your secrets (plain text)
3. Save — sops encrypts automatically

## Adding New Machines

1. Get SSH host key in age format:

   ```bash
   ssh root@newmachine "cat /etc/ssh/ssh_host_ed25519_key.pub" \
     | ssh-to-age
   ```

2. Add age key to `.sops.yaml`
3. Update `sops.age.sshKeyPaths` in the NixOS config
4. Run `sops --updatekeys` on all secret files
5. Deploy with `deploy-rs`

## Troubleshooting

- **"decryption failed: no key for this recipient"** — Machine's SSH host age key isn't in `.sops.yaml`
- **"no key matches the criteria"** — `.sops.yaml` creation_rules don't match file path
- **Secret not appearing** — Check `sops.defaultSopsFile` path is correct
