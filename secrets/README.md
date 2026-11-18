# Secrets Management with sops-nix

## Age-based Setup

- **Admin age key** — for editing secrets on Mac (`~/.config/sops/age/keys.txt`)
- **Machine age keys** — derived from SSH host keys (`homelab-3070`)

## Directory Structure

One directory per machine that decrypts. The directory *is* the policy: the
`creation_rules` in `.sops.yaml` are scoped to `secrets/hosts/<host>/`, so
adding a file there picks up that host's recipients automatically and a
same-named file elsewhere in the repo can't silently inherit them.

```
secrets/
├── hosts/
│   ├── macair/            # admin key only — nothing else mounts these
│   │   ├── macair.yaml    # scalars: git-napatsc-token, smb-password
│   │   ├── auth.json      # opencode API keys (whole-file, pi)
│   │   ├── go-bars.json   # pi workspace/cookie (whole-file)
│   │   └── models.json    # model providers incl. api keys (whole-file)
│   └── homelab-3070/
│       └── k3s.yaml       # k3s-token (agent join)
└── README.md
```

`homelab-n150` has no directory: it is the k3s **server**, generates its join
token on disk (`/var/lib/rancher/k3s/server/token`) and decrypts nothing.
`linode-us` has no secrets either.

### The split inside a host directory

Mechanical, not case-by-case:

| Kind | Where | sops-nix declaration |
| --- | --- | --- |
| scalar (token, password) | `<host>.yaml`, one key each | `key = "<name>"` |
| structured blob | its own file | `key = ""` (whole file) |

A blob **cannot** move into `<host>.yaml`. sops-nix's `key` option documents
that "no tested data structures are supported", so extracting a nested object
is unsupported; `sops` can address leaves (`["a"]["b"]["c"]`) but the installer
path is untested. pi also reads `auth.json`, `models.json` and `go-bars.json`
as three distinct files, so they stay separate by contract anyway.

Keeping blobs separate also keeps them independently grantable: a future
machine can be given just the git token without every provider API key.

## Editing Secrets

Run `sops` from the repo root — the creation rules match on the leading path.

```bash
sops secrets/hosts/macair/macair.yaml
sops secrets/hosts/macair/models.json
sops secrets/hosts/homelab-3070/k3s.yaml
```

## How It Works

### NixOS (homelab-3070, homelab-n150, linode-us)

- sops-nix decrypts declared secrets at boot using SSH host age keys
- Secrets available at `config.sops.secrets.<name>.path`
- Used for: k3s token (agent join)

### macOS (macair)

- sops-nix decrypts secrets via launchd agent at login
- Secrets symlinked to `~/.config/sops-nix/secrets/<name>`
- Pi program symlinks secrets to `~/.config/pi/`

### Whole-file encryption

- `key = ""` means the entire file content is the secret
- Used for `auth.json`, `go-bars.json` and `models.json`

## Adding New Secrets

1. Pick the directory of the machine that needs it (create
   `secrets/hosts/<host>/` if this is a new machine)
2. Scalar → add a key to `<host>.yaml`; blob → `sops` creates a new file.
   Either way sops applies that directory's recipients
3. Declare it in the consumer's Nix module via `sops.secrets.<name>`

Adding a file under an existing `secrets/hosts/<host>/` needs no `.sops.yaml`
change. Adding a *new host* does.

## Adding New Machines

1. Get SSH host key in age format:

   ```bash
   ssh root@newmachine "cat /etc/ssh/ssh_host_ed25519_key.pub" \
     | ssh-to-age
   ```

2. Add the age key to `.sops.yaml` and a `path_regex` for
   `secrets/hosts/<newhost>/`
3. Create the host's secret files under `secrets/hosts/<newhost>/`
4. Update `sops.age.sshKeyPaths` in that host's NixOS config
5. Deploy with `deploy-rs`

## Rotating / removing a key

```bash
# drop a single key from a multi-key file
sops unset secrets/hosts/macair/macair.yaml '["old-key"]'

# re-apply .sops.yaml recipients after a change to the rules
sops --updatekeys secrets/hosts/macair/macair.yaml
```

## Troubleshooting

- **"decryption failed: no key for this recipient"** — the age key isn't in
  that file's `sops.recipient` list; check the `path_regex` for its directory
  in `.sops.yaml`
- **"no matching creation rules found"** — `sops` was run from a subdirectory,
  or the file sits outside `secrets/hosts/<host>/`
- **Secret not appearing** — check `sops.defaultSopsFile` (or the secret's own
  `sopsFile`) points at the new path, and that `format` matches the file
  (`yaml` for `<host>.yaml`, `json` for the pi blobs)
