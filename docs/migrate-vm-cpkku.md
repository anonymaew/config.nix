# Migrating `vm-cpkku` to NixOS + k3s (`cpkku` namespace)

> **STATUS: PLAN — not executed.** Evidence in §1 was gathered live on
> 2026-11-17 (`kubectl`, `ssh vm-cpkku`, `openssl`/`dig`/`curl` from macair and
> from inside the KKU LAN). Re-verify §1 before executing; the box's podman
> stacks and the cluster are both drifting.
>
> Install mechanics are a variant of
> [`install-nixos-on-homelab-3070.md`](install-nixos-on-homelab-3070.md) —
> read that first, this document only records what is *different*.

**Scope:** wipe `vm-cpkku` (Ubuntu 26.04, KKU network, Bangkok) → NixOS via
`nixos-anywhere` + disko → join the existing homelab k3s cluster as an **agent**
→ move its rootless-podman stacks into the cluster as Kustomize apps in
namespace `cpkku`, deployed from `~/code/homelab-helm` → give the node its own
ingress (`llm.nonsakhoo.com` via Cloudflare Tunnel;
`ai-dday.computing.kku.ac.th` via the university's reverse proxy → node :443).

Out of scope: the pre-existing `cpkku/` objects that serve the college site
(`cpkku-next-*`, `kaen-coon-doc`). They are still not in git and their PVs are
node-pinned to `homelab-n150`; this migration neither touches nor adopts them
(see `homelab-helm/doc/architecture.md` §Namespaces).

---

## 1. Evidence: what is running today

### 1.1 Cluster (homelab)

| Thing | Value |
| --- | --- |
| Nodes | `homelab-n150` (control-plane,etcd, `storage-tier=large`), `homelab-3070` (`storage-tier=nvme`) |
| k3s | `v1.36.5+k3s1`, `--disable=traefik`, `--disable=local-storage` |
| Pod network | flannel VXLAN, `--flannel-iface=tailscale0`, `--node-ip=<tailnet IP>` on both nodes |
| Edge | agentgateway `v1.7.0`, Gateway `edge-gateway` (ns `default`), NodePorts **31557/32724** (load-bearing, `linode-us` DNATs to them) |
| TLS | cert-manager + Let's Encrypt **DNS01 via Cloudflare**, wildcard `napatsc-cert` (SANs: `napatsc.net`, `*.napatsc.net`, `*.napatsc.com`, `*.maps.napatsc.com`) |
| Storage | `local-path` (`/var/lib/rancher/k3s/storage`, every node, `WaitForFirstConsumer`), `local-large` (n150 HDD only) |
| Policies | `ValidatingAdmissionPolicy` for image pinning + resource requests, **scoped to namespace `homelab` only** |

### 1.2 `vm-cpkku` (Ubuntu 26.04.1, KVM guest)

| Thing | Value |
| --- | --- |
| Hardware | 16 vCPU / 14 GiB RAM / `sda` 300 GB |
| Firmware | **legacy BIOS** (i440FX/SeaBIOS, **no EFI**, no `/sys/firmware/efi`), `sr0` CD-ROM present |
| Disk | LVM: `sda3` (298 G) → `ubuntu-vg/ubuntu-lv` **100 G only**, mounted `/`; `sda2` = `/boot` 2 G; `sda1` = 1 M |
| Network | `ens18` DHCP `10.198.110.45/24`, gw `10.198.110.254`, DNS `10.101.102.1` |
| Tailnet | `100.64.31.82`, **offers exit node**, direct peer from macair at **270 ms RTT** |
| Users | `napatsc` (sudo), `bdi-data`, `group-demo`, `medical` |
| Failed units | `logrotate.service` (cosmetic) |
| Installed | `nix`/`k3s`: **no**; `docker` (unusable: user not in group); rootless `podman 5.7.0` |
| LAN access | jump host **`dinc-vm-cpkku`** = `dinc49`, Ubuntu 24.04.5, `project@10.198.110.49/24`, **1 ms** from vm-cpkku. **SSH bridge only** — no `nix`, no packages added; it just forwards TCP (`git`/`curl`/`rsync`/`openssl`/`docker` happen to be present) |
| LAN SSH | `project@dinc49`'s ed25519 key (comment `dinc-vm-cpkku (10.198.110.49) -> hosts`, no passphrase — batch SSH) was **generated 2026-11-17 and appended to `napatsc@vm-cpkku:~/.ssh/authorized_keys`**; both `dinc49 → vm-cpkku` and `macair -J project@dinc-vm-cpkku → vm-cpkku` are verified. Root on vm-cpkku is **not** keyed; `nixos-anywhere --sudo` handles that itself (§P2). |

Running rootless-podman stacks (`~napatsc/services/`):

| Compose stack | Containers | Ports | Data |
| --- | --- | --- | --- |
| `proxy` | `traefik:v3.6`, `cloudflared:latest` (token tunnel) | `443` | `config/certs/local.crt` = **self-signed `CN=localhost`** |
| `ai-dday` | `oven/bun:latest` → `bun build/index.js` | `3000` (routed by traefik, `Host(ai-dday.computing.kku.ac.th)`) | `./data` = whole app dir, **910 M** (build 759 M, node_modules 133 M) |
| `ai-gateway` | `litellm:main-stable`, `postgres:16` (16.15), `nginx:stable-alpine` (TLS :443→litellm:4000, published `11434`), `prom/prometheus` | `4000`, `11434`, `9090` | postgres DB **223 MB** (279 M on disk), prometheus 1.9 M |
| `bdi-monitor` | `prom/prometheus:v3`, `grafana/grafana:latest` — **currently stopped**, volumes only | `9091`, `3000` | prometheus 968 M, grafana 52 M |

Other data on the box: `~/medical/` 2 GB of CSVs, `~/services/ai-dday/data` 910 M.
Image store: 42 images / 23.8 GB.

`ai-gateway/config.yml` is the load-bearing detail: every model points at a
**KKU-LAN-only** endpoint (`http://10.198.199.202:8000`,
`http://10.198.199.203:58009/v1`), plus two `pass_through_endpoints` to the same
hosts. The workloads therefore **cannot** run anywhere but this node (or another
host inside 10.198/16).

### 1.3 Ingress and DNS facts (the part that decides the design)

`llm.nonsakhoo.com`

- Resolves to Cloudflare (`104.21.19.178`, `172.67.187.10`); zone `nonsakhoo.com`
  is served by `sunny/vicky.ns.cloudflare.com`. Proxied (orange cloud) today.
- `curl https://llm.nonsakhoo.com/health/liveliness` → `200 "I'm alive!"`
  (`server: cloudflare`), i.e. TLS terminates at Cloudflare and the origin leg
  is the token tunnel → traefik:443 (self-signed) → litellm:4000.
- ⇒ Cloudflare Tunnel, no cluster-side certificate needed. Keep the tunnel.

`ai-dday.computing.kku.ac.th`

- Resolves to `rev-proxy-c02.kku.ac.th` (**202.28.118.202**). The zone is **not**
  on Cloudflare — so the existing DNS01-only `ClusterIssuer` cannot issue for it.
- The university proxy presents a **Let's Encrypt `CN=*.computing.kku.ac.th`**
  certificate (valid `Oct 19 2026 → Jan 17 2027`) and serves **only one cert in
  the chain** (no intermediate — `curl` fails verification, browsers usually
  paper over it via AIA).
- From macair (US): `403` from a **"Web Application Firewall"** page.
  From `vm-cpkku` (KKU LAN): `200`. So the university WAF fronts it and
  geo/IP-restricts; test this hostname **from Thailand**, never from macair.
- Today's origin is traefik on **:443 with a self-signed `CN=localhost` cert**,
  i.e. the university proxy re-encrypts to the origin **without verifying** the
  origin certificate.
- ⇒ TLS is terminated *at the university*, the node only needs a TLS listener on
  :443 with *a* certificate. Do not burn a budget on public PKI here; confirm the
  no-verify behaviour with KKU IT before relying on it (§9).

### 1.4 Network reality

`tailscale ping vm-cpkku` → `270 ms` direct (via `202.28.119.64:41641`).
`tailscale ping homelab-n150` → `23 ms` via DERP `sfo`. Everything the node joins
is therefore a **WAN cluster**: kubelet↔apiserver heartbeats, CoreDNS lookups,
and flannel VXLAN all cross the Pacific. See §9.1.

---

## 2. Target state

```text
                    ┌──────────── Cloudflare (edge TLS) ────────────┐
   llm.nonsakhoo.com ─► proxied DNS ─► Tunnel ─► cloudflared pod    │
                    │                              │ (ns cpkku, on vm-cpkku)
                    │                              ▼
                    │                       th-gateway :80  ─► HTTPRoute ─► ai-gateway-litellm:4000
                    │
   ai-dday.computing.kku.ac.th
        │
        ▼  KKU rev-proxy-c02 (LE *.computing.kku.ac.th, WAF) — L4/re-encrypt
        ▼  →  vm-cpkku:443   (host nftables dnat → nodePort 31443)
                             │
                        th-gateway :443 (TLS terminate, self-signed origin cert)
                             └─► HTTPRoute ─► ai-dday-server:3000

   k3s control plane: homelab-n150 (100.89.132.36:6443, tailnet)
        ▲ agent, flannel over tailscale0, node-ip = vm-cpkku tailnet IP
   vm-cpkku  node labels: storage-tier=thai
             taint:        cpkku-site=true:NoSchedule
             storage:      local-path → /var/lib/rancher/k3s/storage (root PV)
```

New objects:

| Kind | Names |
| --- | --- |
| Gateway / Parameters | `Gateway/th-gateway`, `AgentgatewayParameters/th` (ns `cpkku`) |
| TLS | `ClusterIssuer/selfsigned` (one-off), `Certificate/cpkku-origin-tls` → Secret `cpkku-origin-tls` |
| `ai-gateway/` | `ai-gateway-litellm` (+ Service 4000), `ai-gateway-db` postgres (+ Service 5432, PVC 5Gi) |
| `ai-dday/` | `ai-dday-server` (+ Service 3000, PVC 3Gi) |
| `llm-edge/` | `llm-edge-cloudflared` (Deployment, no Service) |
| Routes | `ai-gateway-route` → `llm.nonsakhoo.com`; `ai-dday-route` → `ai-dday.computing.kku.ac.th` |

---

## 3. Decisions

| # | Decision | Choice | Why |
| --- | --- | --- | --- |
| D1 | Cluster role | **agent** (never server/etcd) | 270 ms from etcd = cluster-wide stalls |
| D2 | Placement | `nodeSelector: kubernetes.io/hostname=vm-cpkku` **+ taint** `cpkku-site=true:NoSchedule` | Model traffic targets `10.198.199.202/203`; nothing unrelated may drift onto a WAN node |
| D3 | Namespace | `cpkku` (pre-existing, 287 d old) | user-facing grouping; pre-existing college objects keep their names, new ones are `<svc>-` prefixed |
| D4 | Orchestration | everything in k8s via `homelab-helm` dirs — **no `virtualisation.oci-containers`** | one deployment model, routes/secrets/policies in git |
| D5 | `llm.nonsakhoo.com` | keep Cloudflare Tunnel; run `cloudflared` as an in-cluster Deployment | origin is NAT'd in KKU; tunnel is the only path |
| D6 | `ai-dday.computing.kku.ac.th` | keep the university proxy; terminate TLS **in-cluster** on :443 with a cert-manager **self-signed** cert | LE cannot issue (DNS on KKU, no public 80 path); origin cert is not verified today |
| D7 | Thai edge | second `Gateway` (`th-gateway`) on the new node, Service type **NodePort**, pinned 31080/31443, host `dnat` 80/443 → those | keeps Gateway API routes in git; avoids klipper-lb binding 80/443 on the homelab nodes |
| D8 | DB migration | **`pg_dump`**, never a volume copy | the named podman volume reads as empty from the host while the DB is 279 M inside the container |
| D9 | Install path | `nixos-anywhere` **from inside 10.198.110.0/24**, with a Tailscale auth key in the first profile | the tailnet IP dies with the disk; the installer has no tailscale (§9.3) |
| D10 | `bdi-monitor` | **retire**: export the Grafana dashboards, do not port Prometheus/Grafana | the cluster already runs both; the 16 scrape targets are KKU LAN node-exporters (`10.198.110.201-216`) — add them to the cluster Prometheus instead |
| D11 | Taint cost | pay it: tolerations in every Thai workload, node-exporter, and the local-path **helper pod** | without the helper-pod toleration, PVCs on the node hang forever (§9.4) |

Open questions — blocking (§9 + §10, keep them ticked off before P2):

1. KVM console / snapshot access. LAN reachability itself is solved:
   `dinc-vm-cpkku` is the SSH bridge (its key is already on vm-cpkku, and it
   needs no software installed). `--sudo` covers root on vm-cpkku, so no root key
   work is needed either — but the sudo password must be to hand.
2. KKU IT: does `rev-proxy-c02` verify the origin certificate, and does it forward
   `Host` + `X-Forwarded-Proto`? (evidence says "no verify, re-encrypt to :443")
3. Cloudflare: locally-managed tunnel (credentials JSON in sops, config in git)
   or keep the dashboard-managed token tunnel? Recommend locally-managed.
4. Keep the exit-node advertisement (`--advertise-exit-node`) on the new node?
5. `~/medical` (2 GB CSVs) and `~/services/*` data: keep on the box under `/srv`,
   or move to `homelab-n150` `/mnt/hdd`?
6. Maintenance window length: from wipe (P2) to first working `llm.nonsakhoo.com`
   (P5) — estimate 3–5 h, of which ~1 h is the install itself.

---

## 4. Work items

### 4.1 `config.nix`

```text
hosts/vm-cpkku/
├── default.nix               # host-specific NixOS config (below)
├── disk-config.nix           # disko, destructive — BIOS layout
└── hardware-configuration.nix# kernel modules only; NO fileSystems (disko owns them)
```

`modules/nixos.nix`:

```nix
config.flake.nixosConfigurations.vm-cpkku = mkHost {
  host = "vm-cpkku";
  extraModules = [ inputs.disko.nixosModules.disko ];
};
```

`output.nix` — `hostname` is the **new tailnet IP** (stable per node key), and
`sshOpts` needs a longer `ConnectTimeout` for the 270 ms path:

```nix
deploy.nodes.vm-cpkku = {
  hostname = "100.x.y.z";                 # ← from P2, not the old 100.64.31.82
  sshOpts = [ "-o" "ConnectTimeout=20" "-o" "StrictHostKeyChecking=accept-new" ];
  interactiveSudo = false;
  profiles.system = { sshUser = "root"; user = "root";
    path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.vm-cpkku; };
};
```

`secrets/.sops.yaml` — new anchor + a rule scoped to the host directory (created
in P3, after the real host key exists):

```yaml
creation_rules:
  - path_regex: (^|/)secrets/hosts/vm-cpkku/
    key_groups:
      - age: [ *admin_age, *vm_cpkku_age ]
```

`hosts/vm-cpkku/default.nix` — the points that differ from `homelab-3070`:

```nix
{ user, lib, config, ... }:
{
  imports = [ ./hardware-configuration.nix ./disk-config.nix ];

  system.stateVersion = "26.11";          # first switch is 26.11; never bump
  # Legacy BIOS/QEMU: no EFI, so GRUB on the disk (systemd-boot is not an option).
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  # disko emits fileSystems/swapDevices — hardware-configuration.nix must not.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  networking.hostName = "vm-cpkku";
  networking.enableIPv6 = true;
  time.timeZone = lib.mkForce "Asia/Bangkok";   # base sets America/Los_Angeles

  nix.settings.builders-use-substitutes = lib.mkForce false;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [ user.sshKey ];

  # ── Tailscale ─────────────────────────────────────────────────────────
  # authKeyFile is what makes a headless reinstall possible: the box rejoins the
  # tailnet on first boot with no interactive `tailscale up`. Populate the file
  # through `nixos-anywhere --extra-files` in P2 and delete it afterwards;
  # /var/lib/tailscale then owns the identity.
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/lib/tailscale/authkey";
    extraUpFlags = [ "--advertise-exit-node" ];   # drop if open question 4 says so
  };

  # ── sops (join token only, P3 onwards) ────────────────────────────────
  # Deliberately absent in the P2 profile: the age recipient is derived from the
  # host key that the install itself generates.
  sops = {
    defaultSopsFile = ../../secrets/hosts/vm-cpkku/k3s.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.generateKey = true;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
  sops.secrets.k3s-token = { };

  # ── k3s agent ─────────────────────────────────────────────────────────
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://100.89.132.36:6443";
    tokenFile = config.sops.secrets.k3s-token.path;
    extraFlags = [
      "--node-name=vm-cpkku"
      "--node-ip=100.x.y.z"                  # ← new tailnet IP
      "--node-external-ip=100.x.y.z"
      "--flannel-iface=tailscale0"
      "--node-label=storage-tier=thai"       # never large|nvme: those SCs are US-only
      "--node-taint=cpkku-site=true:NoSchedule"
      "--kubelet-arg=node-status-update-frequency=30s"   # WAN: fewer API round-trips
    ];
  };
  systemd.services.k3s.after = [ "tailscaled.service" "network-online.target" ];
  systemd.services.k3s.wants = [ "tailscaled.service" "network-online.target" ];

  systemd.services."k3s-storage-dirs" = {
    serviceConfig.Type = "oneshot";
    script = "mkdir -p /var/lib/rancher/k3s/storage";
    wantedBy = [ "multi-user.target" ];
  };

  # ── Ingress: KKU rev-proxy speaks TLS to :443, kube-proxy owns 31443/31080 ──
  # Same shape as hosts/linode-us/default.nix (dnat in, no masquerade needed
  # because the destination becomes a local address).
  networking.nftables.tables.cpkku-ingress = {
    family = "ip";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "ens18" tcp dport 443 dnat ip to 100.x.y.z:31443
        iifname "ens18" tcp dport 80  dnat ip to 100.x.y.z:31080
      }
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [ 22 9100 10250 31080 31443 ];
    allowedUDPPorts = [ 8472 41641 ];
  };
}
```

`hosts/vm-cpkku/disk-config.nix` — **BIOS** layout, whole 300 G disk (the Ubuntu
LV only used 100 G of it):

```nix
{ disko.devices.disk.main = {
  type = "disk";
  device = "/dev/sda";                       # verify with lsblk in the installer
  content = { type = "gpt"; partitions = {
    bios = { size = "1M"; type = "21686148-6449-6E6F-744E-656564454649"; };
    boot = { size = "1G"; content = {
      type = "filesystem"; format = "ext4"; mountpoint = "/boot";
    }; };
    swap = { size = "8G"; content = { type = "swap"; }; };
    root = { size = "100%"; content = {
      type = "filesystem"; format = "ext4"; mountpoint = "/";
      mountOptions = [ "noatime" ];
    }; };
  }; };
}; }
```

### 4.2 `homelab-helm`

Start every app dir from `homelab-helm/doc/template/` and follow
`homelab-helm/doc/pattern.md` — the notes below are only the deltas. Namespace
is `cpkku` in every overlay (the repo already spans four namespaces;
`namespace:` stays per service).

```text
ai-gateway/                     namePrefix ai-gateway-   namespace cpkku
├── kustomization.yml
├── base/
│   ├── deployment-litellm.yml   image pinned to the digest running today
│   ├── deployment-db.yml        postgres:16.15, runAsUser 999, PVC db-data 5Gi, Recreate
│   ├── service-litellm.yml      4000
│   ├── service-db.yml           5432
│   ├── pvc-db-data.yml          local-path 5Gi
│   ├── configmap-db.yml         POSTGRES_DB=litellm, POSTGRES_USER=llmproxy
│   └── httproute-llm.yml        parentRefs th-gateway, host llm.nonsakhoo.com
├── config/litellm-config.yml    ← configMapGenerator (hash on: config edits roll pods)
├── secrets/litellm-env.env      LITELLM_MASTER_KEY, LITELLM_SALT_KEY   (+ .example/.enc)
└── secrets/db.env               POSTGRES_PASSWORD (rotated)            (+ .example/.enc)

ai-dday/                        namePrefix ai-dday-     namespace cpkku
├── kustomization.yml
├── base/
│   ├── deployment-server.yml    oven/bun pinned, command bun build/index.js, Recreate
│   ├── service-server.yml       3000
│   ├── pvc-data.yml             local-path 3Gi  (app dir: build 759M + node_modules 133M)
│   └── httproute-ai-dday.yml    parentRefs th-gateway, host ai-dday.computing.kku.ac.th
└── README.md

th-gateway/                     no namePrefix — objects declare namespace: cpkku
├── kustomization.yml
├── gateway.yml                  AgentgatewayParameters/th + Gateway/th-gateway
├── certificate.yml              Certificate/cpkku-origin-tls (issuerRef selfsigned)
└── issuer.yml                   ClusterIssuer/selfsigned (cluster-scoped, apply once)

llm-edge/                       namePrefix llm-edge-    namespace cpkku
├── kustomization.yml
├── base/deployment-cloudflared.yml   pinned cloudflared, nodeSelector, toleration
├── config/cloudflared-config.yml     tunnel ingress → http://th-gateway:80
└── secrets/tunnel-credentials.json   (+ .example/.enc)   [if locally-managed]
```

`th-gateway/gateway.yml` (mirrors `agentgateway/gateway.yml`, one node, no
load balancer):

```yaml
apiVersion: agentgateway.dev/v1alpha1
kind: AgentgatewayParameters
metadata: { name: th, namespace: cpkku }
spec:
  logging: { format: json, level: info }
  deployment:
    spec:
      replicas: 1                       # single node: 2 replicas buys nothing
      template:
        metadata:
          annotations:
            prometheus.io/scrape: "true"     # cluster Prometheus scrapes by pod
            prometheus.io/port: "15020"      # annotation, not ServiceMonitor
            prometheus.io/path: /metrics
        spec:
          nodeSelector: { kubernetes.io/hostname: vm-cpkku }
          tolerations:
            - { key: cpkku-site, operator: Exists, effect: NoSchedule }
  service:
    spec:
      # NodePort, NOT LoadBalancer: a LoadBalancer makes k3s servicelb bind the
      # *service* ports (80/443) on EVERY node via a new svclb DaemonSet — the
      # homelab nodes must not start listening on 80/443.
      type: NodePort
      ports:
        - { name: listener-80,  port: 80,  targetPort: 80,  protocol: TCP, nodePort: 31080 }
        - { name: listener-443, port: 443, targetPort: 443, protocol: TCP, nodePort: 31443 }
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: th-gateway, namespace: cpkku }
spec:
  gatewayClassName: agentgateway
  infrastructure:
    parametersRef: { name: th, group: agentgateway.dev, kind: AgentgatewayParameters }
  listeners:
    - name: web
      protocol: HTTP
      port: 80
      allowedRoutes: { namespaces: { from: All } }
    - name: websecure
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs: [ { kind: Secret, name: cpkku-origin-tls } ]
      allowedRoutes: { namespaces: { from: All } }
```

Routes are **hand-written**, not `components/public-route` — that component
hardcodes `parentRefs: edge-gateway/default`. Copy
`degoog/base/httproute-mcp.yml`'s shape instead:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: route, namespace: cpkku }        # → ai-dday-route / ai-gateway-route
spec:
  parentRefs: [ { name: th-gateway, namespace: cpkku } ]
  hostnames: [ ai-dday.computing.kku.ac.th ]
  rules:
    - matches: [ { path: { type: PathPrefix, value: / } } ]
      backendRefs: [ { name: ai-dday-server, port: 3000 } ]   # FINAL prefixed name
```

Shared changes in `homelab-helm` (small but load-bearing):

1. **`local-path-storage/standalone.yml` + `large.yml`** — the `setup` script
   chowns only `*_homelab_*` and known exceptions, so a `cpkku` PVC is left
   `root:root 0700` and the app cannot write. Add:

   ```sh
   *_cpkku_ai-gateway-db-data)  chown 999:999   "${VOL_DIR}" ;;  # postgres
   *_cpkku_*)                   chown 1000:1000 "${VOL_DIR}" ;;
   ```

   and add a toleration to the **helper pod** template in both files (it has none
   today, so a `NoSchedule` taint means "helper pod unschedulable" and PVCs hang):

   ```yaml
   spec:
     tolerations:
       - { key: cpkku-site, operator: Exists, effect: NoSchedule }
   ```

2. **`policy/`** — `workload-image-pinning` and `workload-resource-requests`
   match only `kubernetes.io/metadata.name: homelab`. Extend both
   `namespaceSelector.matchExpressions` to an `In [homelab, cpkku]` list so the
   new apps cannot regress to `:latest` or "no requests".
3. **`prometheus/`** — add the node-exporter toleration for the new node and the
   16 KKU LAN targets from `bdi-monitor` (extra scrape job), so the retired
   stack's coverage is not lost.
4. **`doc/architecture.md` / `README.md`** — node table, namespace table
   (`cpkku` becomes "partly in git"), and the service inventory entries.
5. **`cd-handoff.md`** — `cpkku` stops being "live but not in this repo" for the
   three new dirs; the college-site objects remain out of scope.

### 4.3 Ingress wiring

| Path | Steps |
| --- | --- |
| `llm.nonsakhoo.com` | Cloudflare Tunnel (`cloudflared`, ns `cpkku`, on vm-cpkku) → `http://th-gateway:80` → HTTPRoute → `ai-gateway-litellm:4000`. CF terminates TLS; the origin leg is plain HTTP inside the cluster (drops today's nginx + self-signed 11434 hop). |
| `ai-dday.computing.kku.ac.th` | University proxy → `vm-cpkku:443` → host `dnat` → `nodePort 31443` → `th-gateway` TLS (self-signed `cpkku-origin-tls`) → HTTPRoute → `ai-dday-server:3000`. Port 80 is opened the same way (31080) for future ACME/HTTP needs. |
| Direct/internal | `litellm` clients inside the KKU LAN keep using the in-cluster Service through `kubectl port-forward`, or the tunnel hostname. The old `:11434` self-signed endpoint is **retired** — update clients that point at it. |

`ClusterIssuer/selfsigned` + `Certificate` (only if D6 holds):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: selfsigned }
spec: { selfSigned: {} }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: cpkku-origin-tls, namespace: cpkku }
spec:
  secretName: cpkku-origin-tls
  dnsNames: [ ai-dday.computing.kku.ac.th ]
  issuerRef: { name: selfsigned, kind: ClusterIssuer }
```

---

## 5. Runbook

### P0 — freeze and export (no downtime)

```sh
# cluster safety net
ssh -t root@100.89.132.36 'sudo k3s etcd-snapshot save && sudo k3s etcd-snapshot ls | tail -3'
kubectl get all,cm,pvc,httproute -n cpkku -o yaml > ~/cpkku-live-$(date +%F).yaml   # reference only

# vm-cpkku exports (do these BEFORE the wipe; they are the only copies)
rsync -a --info=progress2 vm-cpkku:~/services/ ~/backup/vm-cpkku/services/
rsync -a --info=progress2 vm-cpkku:~/medical/  ~/backup/vm-cpkku/medical/
ssh vm-cpkku 'podman exec litellm_db pg_dump -U llmproxy -d litellm -Fc' > ~/backup/vm-cpkku/litellm.dump
ssh vm-cpkku 'tar -C ~/services/bdi-monitor -cf - grafana/dashboards' | tar -C ~/backup/vm-cpkku -xf -
```

- Verify `pg_restore -l litellm.dump | head` on the dump.
- Rotate the leaked secrets while you are here: the **Cloudflare tunnel token**
  and the litellm DB password (`dbpassword9090`, in a plaintext compose file and
  in `DATABASE_URL`). Keep `LITELLM_MASTER_KEY`/`LITELLM_SALT_KEY` unchanged —
  clients and the spend table depend on them.
- Create a Tailscale **auth key**: reusable, pre-authorized, non-ephemeral,
  tagged for servers. It only needs to live until P3.
- Confirm the KVM snapshot + console (open question 1). Snapshot is the rollback.

### P1 — repo scaffolding (still no infra change)

- `config.nix`: `hosts/vm-cpkku/*`, `modules/nixos.nix`, `output.nix`
  (placeholder IP), this document.
- `homelab-helm`: the four dirs, the shared changes in §4.2, secrets via
  `scripts/secrets.sh encrypt`.
- Gates:

```sh
nix flake check && nix build .#nixosConfigurations.vm-cpkku.config.system.build.toplevel --dry-run
kubectl kustomize ../homelab-helm/ai-gateway/ >/dev/null
kubectl kustomize ../homelab-helm/th-gateway/ >/dev/null
../homelab-helm/scripts/secrets.sh status
git add -A            # flakes read the index, not the worktree
```

### P2 — install NixOS (window opens)

Run over the KKU LAN. **`dinc-vm-cpkku` is only an SSH bridge**: it needs `sshd`
and the key that is already in its `~/.ssh`, nothing else. **Do not install `nix`
(or anything else) on it.** `nixos-anywhere` runs on macair, which already has an
x86_64-linux builder (`nixosVmBasedLinuxBuilder` + `distributedBuilds` in
`hosts/macair/default.nix`), so the target closure is built locally and copied.

| Route | When |
| --- | --- |
| `macair` → `napatsc@10.198.110.45` through the bridge | normal path. `--ssh-option ProxyJump=project@dinc-vm-cpkku` makes the jump part of **every** phase, including the post-kexec installer session — no software on the bridge |
| same, against a **new address** | if the installer takes a different DHCP lease (§ recovery below) |
| KVM console + NixOS ISO on `sr0` | if kexec is blocked, or SSH into the installer is impossible |

Both `dinc49 → vm-cpkku` (key authorized, no password) and
`macair -J project@dinc-vm-cpkku → vm-cpkku` were verified on 2026-11-17.

`--ssh-option` takes the *value* of an `ssh -o` option (nixos-anywhere turns it
into `-o <value>`), so a jump host is spelled **`ProxyJump=…`**, not `-J …`.

Two behaviours of nixos-anywhere 1.13 worth knowing before the window:

- It generates its own install key and `ssh-copy-id`s it (the first connection
  falls back to your agent keys because it passes `IdentitiesOnly=no`), so
  `napatsc@` + `--sudo` is enough — no root key has to be installed by hand. After
  kexec it switches to `root@<host>` on its own.
- `--sudo` needs an interactive terminal for the password prompt. Run the command
  in a real shell, not through a non-tty wrapper.

If the installer comes up on a different address than `10.198.110.45`, split the
run — the bridge is still all you need:

```sh
# 1. kexec only (the address is still Ubuntu's)
nix run github:nix-community/nixos-anywhere -- --flake .#vm-cpkku \
  --target-host napatsc@10.198.110.45 --sudo \
  --ssh-option ProxyJump=project@dinc-vm-cpkku \
  --phases kexec

# 2. find the installer's address from the bridge (ARP/DHCP — read-only)
ssh dinc-vm-cpkku 'ip neigh show dev ens18'

# 3. partition + install against the installer
nix run github:nix-community/nixos-anywhere -- --flake .#vm-cpkku \
  --target-host root@<installer-ip> \
  --ssh-option ProxyJump=project@dinc-vm-cpkku \
  --phases disko,install --build-on remote --extra-files ./secrets/install
```

If jump-host key handling is what breaks, replace `-J` with a plain forward from
the bridge — still no software installed on it:

```sh
ssh -N -L 2222:<installer-ip>:22 project@dinc-vm-cpkku &
# … then --target-host root@127.0.0.1 --ssh-option "-p 2222"
```

The P2 profile is **tailscale on, sops off, k3s off** — the 3070 rule: the age
recipient cannot be known before the install generates the host key. Produce it
on a branch, exactly like `mig/join-homelab-phase1` was used for the control-plane
move:

```sh
git switch -c mig/vm-cpkku-phase1
# in hosts/vm-cpkku/default.nix: `services.k3s.enable = false;` and comment out the
# whole `sops = { … }` block plus `sops.secrets.k3s-token`
git add -A          # flakes read the index
```

P3 then re-enables both on `main` (or `mig/vm-cpkku-phase2`) once the host key is
known.

```sh
# Runs from macair. `--sudo` is what replaces root SSH: nixos-anywhere uploads its
# own install key and copies it into /root itself (needs one interactive sudo
# password; the first connection uses your existing key, which is already
# authorized for napatsc@vm-cpkku). The `--ssh-option` is an `-o` value, so it is
# ProxyJump=… and not -J ….
# secrets/install/ is gitignored: var/lib/tailscale/authkey + root/.ssh/authorized_keys
nix run github:nix-community/nixos-anywhere -- \
  --flake .#vm-cpkku --target-host napatsc@10.198.110.45 --sudo \
  --ssh-option ProxyJump=project@dinc-vm-cpkku \
  --build-on remote --extra-files ./secrets/install
```

- Legacy BIOS: `nixos-anywhere` kexecs successfully from SeaBIOS (no EFI needed).
  If the VM blocks kexec, boot the NixOS ISO from `sr0` on the console and run
  the same command against the installer.
- LVM leftovers: Ubuntu's `ubuntu-vg` PV label can survive; if LVM grabs `sda3`
  after the disko step, `vgchange -an ubuntu-vg && wipefs -a /dev/sda3` (3070 §5).
- Gates: `ssh root@<new tailnet IP>` works; `tailscale ip -4`; `lsblk` shows the
  full 300 G; `systemctl --failed` empty. **Record the new tailnet IP.**

### P3 — sops + k3s join

```sh
ssh root@<ip> 'cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age   # → .sops.yaml
ssh root@homelab-n150 'cat /var/lib/rancher/k3s/server/token' > /tmp/k3s-token
# secrets/hosts/vm-cpkku/k3s.yaml, encrypted to admin + the new host key
nix run github:serokell/deploy-rs -- .#vm-cpkku
ssh root@<ip> 'rm -f /var/lib/tailscale/authkey'      # identity is now in /var/lib/tailscale
```

Gates: `kubectl get nodes -o wide` (Ready, taint + `storage-tier=thai`);
`ls -l /run/secrets/k3s-token` (26.11: systemd credentials — there is no
`sops-install-secrets.service`); storage smoke test (a 10 MiB `local-path` PVC
pinned to the node) — this is the first test of the **helper-pod toleration**;
node-exporter target up in Prometheus.

### P4 — apps and data

`kubectl apply -k` in order: `th-gateway/` (Gateway must exist before routes),
`ai-gateway/`, `ai-dday/`, `llm-edge/`. Then restore:

```sh
kubectl -n cpkku exec -i deploy/ai-gateway-db -- pg_restore -U llmproxy -d litellm --no-owner < litellm.dump
# ai-dday wants its whole app dir back (uid 1000 owns it):
kubectl -n cpkku cp ~/backup/vm-cpkku/services/ai-dday/data ai-dday-server-<pod>:/home/bun/app
```

Gates: `kubectl -n cpkku get pod,pvc` all Running/Bound **on vm-cpkku**;
`kubectl -n cpkku exec deploy/ai-gateway-litellm -- curl -s localhost:4000/health/liveliness`;
a model call through the Service (`/v1/chat/completions` for `typhoon2.5` —
proves the `10.198.199.203` reachability from inside the pod network).

### P5 — ingress cutover

1. Host `dnat` for 80/443 is already in the P3 deploy; verify from the KKU LAN:
   `curl -k https://10.198.110.45/ -H 'Host: ai-dday.computing.kku.ac.th'`.
2. Cloudflare: locally-managed tunnel → CNAME `llm.nonsakhoo.com` →
   `<tunnel-uuid>.cfargotunnel.com` (proxied). If open question 3 keeps the token
   tunnel instead, only the ingress target changes: `http://th-gateway.cpkku:80`.
3. Gates: `curl https://llm.nonsakhoo.com/health/liveliness` → 200 with
   `server: cloudflare`; `curl -sk https://ai-dday.computing.kku.ac.th/` **from
   inside KKU** → 200 (macair will get the WAF 403, which is expected);
   `kubectl -n cpkku get httproute` → both `Accepted=True`, `ResolvedRefs=True`.

### P6 — cleanup, verification, docs

Delete the old token tunnel in Cloudflare once P5 is green; `git rm` the compose
stacks wherever they are mirrored; update `homelab-helm/README.md` inventory,
`doc/architecture.md`, `cd-handoff.md`, `config.nix` `AGENTS.md` host table; and
the follow-ups in §11.

---

## 6. Data to move

| Item | Size | Method |
| --- | --- | --- |
| litellm postgres | 223 MB DB (279 MB on disk) | `pg_dump -Fc` → `pg_restore` (do **not** copy the volume: it reads empty on the host) |
| `ai-dday` app dir | 910 MB | rsync/tar into the PVC before first start, or `kubectl cp` into a scaled-down pod |
| litellm `config.yml` | 4 KB | into git as `ai-gateway/config/litellm-config.yml` (verify no real provider keys: today they are `sk-lol` placeholders) |
| litellm `.env` | 2 keys | sops: `ai-gateway/secrets/litellm-env.env.enc` |
| `bdi-monitor` grafana dashboards | 52 MB of db + JSON | export the JSON into `grafana/dashboards/`; drop the rest (D10) |
| `bdi-monitor` / `ai-gateway` prometheus data | ~970 MB | **disposable** |
| `~/medical`, `~/services` sources | 2 GB + ~1 MB | open question 5: `/srv` on vm-cpkku, or `homelab-n150:/mnt/hdd` |

---

## 7. Verification matrix

| Check | Command | Expected |
| --- | --- | --- |
| Node joined | `kubectl get nodes -o wide` | `vm-cpkku Ready`, tailnet IP, taint `cpkku-site=true:NoSchedule` |
| Taint keeps others off | `kubectl get pod -A -o wide --field-selector spec.nodeName=vm-cpkku` | only cpkku-namespace pods (+ tolerating DaemonSets) |
| Placement | `kubectl -n cpkku get pod -o wide` | every pod on `vm-cpkku` |
| Storage | `kubectl -n cpkku get pvc` | Bound, `local.path.provisioner/selected-node=vm-cpkku` |
| local-path chown | `kubectl -n cpkku exec deploy/ai-gateway-db -- id` + write test | `999`, no permission errors |
| Flannel over WAN | in-cluster `curl` from litellm pod to `ai-dday-server:3000` | 200 (cross-pod over tailscale0) |
| LLM path | `POST /v1/chat/completions` via the HTTPRoute | model answers; upstream `10.198.199.203` reachable |
| ai-dday | from KKU LAN, `https://ai-dday.computing.kku.ac.th/` | 200; TLS served by agentgateway (`CN=ai-dday…`) |
| Cloudflare tunnel | `curl -sI https://llm.nonsakhoo.com/health/liveliness` | 200, `server: cloudflare` |
| Node metrics | Prometheus targets | `node-exporter` for `vm-cpkku` UP |
| Policies | `kubectl apply --dry-run=server -k ai-gateway/` after extending the namespaceSelector | no `:latest` / missing-requests warnings |
| Rollback readiness | KVM snapshot + exports present | both ticked |

---

## 8. Rollback

| Point | Action |
| --- | --- |
| Before P2 | KVM snapshot. Restoring it returns the Ubuntu box with all podman stacks intact. |
| P2 fails mid-install | Reboot the ISO/installer and re-run; nothing outside the VM has changed. |
| P3/P4 fails | Nothing is lost: the old data lives in the P0 exports. `kubectl delete node vm-cpkku` removes a half-joined node harmlessly; the cluster is unaffected (`local-path` PVs on the node are orphaned, intended). |
| P5 fails | Leave the old Cloudflare token tunnel and its route in place until the new path answers 200, then delete it. DNS is the only switch. |
| `ai-dday` breaks at the university proxy | Point the proxy back at the (restored) Ubuntu box, or keep the P2 profile running with the old origin config — this is why the snapshot matters. |

There is **no** way back from the wipe without the snapshot; treat the exports in
P0 as the only copy of `~/services`, `~/medical` and the litellm database.

---

## 9. Gotchas

### 9.1 The node is 270 ms away from the API server

- Everything routed through flannel (CoreDNS, in-cluster Services) pays the RTT.
  Keep the Thai workloads self-contained; keep images on public registries
  (`docker.io`, `ghcr.io`) rather than the in-cluster `images.napatsc.com`
  registry on the N150.
- `--kubelet-arg=node-status-update-frequency=30s` reduces API chatter.
- `kubectl logs/exec` against this node is slow, not broken. Use
  `--request-timeout=60s` when scripting.
- If DNS latency becomes a problem, a `node-local-dns` DaemonSet with the
  `cpkku-site` toleration is the next step (k3s has no built-in nodelocaldns).
- Pod MTU: flannel derives it from `tailscale0` (1280), so pods get ~1230. Fine,
  but do not raise it.

### 9.2 No tailnet survives a wipe

`nixos-anywhere` reconnects to the **installer**, which has no Tailscale — so the
install must be driven from a host that reaches `10.198.110.45` on the KKU LAN.
`dinc-vm-cpkku` (`project@10.198.110.49`) is that host, used **only as an SSH
bridge** — `--ssh-option ProxyJump=project@dinc-vm-cpkku`, or a plain `ssh -L`
forward if the jump gets in the way. Nothing is installed on it; `nixos-anywhere`
and the x86_64-linux build stay on macair. Its ed25519 key is already in
`napatsc@vm-cpkku:~/.ssh/authorized_keys` (added 2026-11-17), and both hops were
verified. Root SSH is not needed: `--sudo` covers the privileged steps, and
nixos-anywhere copies its own install key into `/root` after the first
connection (which falls back to your existing key).

That is also the whole reason for `services.tailscale.authKeyFile` plus
`--extra-files`: after first boot the box rejoins the tailnet unattended, and P3
onwards runs from macair again. The tailnet IP **changes** (new node key); copy
it into `--node-ip` and `output.nix` before the P3 deploy.

### 9.3 Legacy BIOS, not EFI

No `/sys/firmware/efi`; use GRUB on `/dev/sda` and a `bios_grub` GPT partition.
`systemd-boot`, as configured on the other hosts, cannot work here.

### 9.4 A taint breaks PVC provisioning unless the helper pod tolerates it

`local-path-storage`'s `helperPod.yaml` ships **no tolerations**. With
`cpkku-site=true:NoSchedule`, the helper pod is unschedulable on vm-cpkku and
every PVC there sits `Pending` with a cryptic condition. Add the toleration in
`standalone.yml` **and** `large.yml` (one ConfigMap serves the cluster).

### 9.5 `local-path` chowns by namespace name

The `setup` case only matches `*_homelab_*`, so `cpkku` PVCs stay `root:root 0700`.
Postgres (`999`) and the bun app (`1000`) need explicit cases (§4.2). There is no
`else` branch — an unmatched namespace silently loses the chown.

### 9.6 Two Gateways, and why `NodePort` matters

A second `Gateway` creates a second proxy Deployment and Service. If that Service
is `LoadBalancer`, k3s servicelb starts a new `svclb-th-gateway` DaemonSet that
binds the **service** ports (80/443) on **every** node — including the homelab
nodes, which today listen on nothing but 31557/32724. Use `type: NodePort` with
pinned ports and reach them from the host via `dnat`, exactly like `linode-us`
does. Verify at apply time that `AgentgatewayParameters.service.spec.type:
NodePort` is honoured; if the controller forces `LoadBalancer`, stop and
reconsider before deploying (see the fallbacks in §4.3).

### 9.7 The origin certificate for `ai-dday` is self-signed on purpose

Evidence (§1.3): the university terminates TLS with its own LE wildcard and today
re-encrypts to a self-signed `CN=localhost` origin. LE cannot issue for
`computing.kku.ac.th` from here (DNS on KKU, no public HTTP-01 path), so a
cert-manager **self-signed** cert is the correct, honest choice — *provided* KKU
IT confirms the proxy does not verify the origin. If they do verify, the only
options are a cert they issue, or a DNS-01 path we do not have. Also note the
proxy serves an incomplete chain, which breaks `curl`/Java/older Android clients;
that is a university-side bug worth reporting.

### 9.8 Everything is `:latest` today

`litellm:main-stable`, `postgres:16`, `oven/bun:latest`, `cloudflared:latest`,
`prom/grafana`. Pin digests (the P0 `podman images --digests` output is the
source of truth for what is running now). After §4.2 extends the image-pinning
policy to `cpkku`, an unpinned manifest is rejected rather than warned.

### 9.9 The existing `cpkku` objects are not in git and must not be "adopted" here

The college site's 5 deployments keep `local-path` PVs with immutable
`nodeAffinity: homelab-n150`. Nothing in this plan moves them, and nothing in
this plan may reuse their names — hence the `ai-gateway-`/`ai-dday-` prefixes.

### 9.10 Deploying over a 270 ms link

`deploy-rs` pushes a multi-GB closure. Do the first deploy with
`--build-on remote` (or pre-seed with `nix copy` while still on the LAN in P2),
then only the delta crosses the ocean.

---

## 10. Before P2 — checklist

- [ ] KVM snapshot taken, console access confirmed (open question 1).
- [ ] LAN hop verified: `ssh -J project@dinc-vm-cpkku napatsc@10.198.110.45`, and
      the sudo password for `napatsc` on vm-cpkku is to hand (for `--sudo`).
- [ ] `pg_dump` restored successfully somewhere (test the restore, not just the dump).
- [ ] `~/services` + `~/medical` rsynced off the box and verified.
- [ ] Cloudflare tunnel token + litellm DB password rotated; new tunnel decided (open question 3).
- [ ] Tailscale auth key created (reusable, pre-authorized, non-ephemeral).
- [ ] KKU IT answered the origin-TLS question (open question 2).
- [ ] `nix flake check` clean; `kubectl kustomize` clean; secrets encrypted.
- [ ] Maintenance window agreed (open question 6) and announced to anyone using
      `llm.nonsakhoo.com` / `ai-dday.computing.kku.ac.th`.

## 11. Follow-ups (after the migration)

- [ ] Decide the fate of the pre-existing `cpkku` college-site objects (adopt or
      document as permanently out of git).
- [ ] Add a `node-local-dns` DaemonSet if DNS latency from Thai pods is felt.
- [ ] Consider a Thai-side image mirror or `imagePullPolicy` audit for the node.
- [ ] Wire the KKU LAN node-exporter targets (`10.198.110.201-216`) into the
      cluster Prometheus with a file_sd watch.
- [ ] Revisit `--advertise-exit-node` (does a Bangkok exit node still make sense?).
- [ ] If Flux starts reconciling, `cpkku` must be in the sync root and the
      cluster-local secrets must be decryptable by the controller.
