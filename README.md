# Homelab Ansible

Provisioning and configuration for an OpenWrt router and Debian/Ubuntu servers.

## Requirements

- Ansible 2.18+
- Python 3.10+
- `sshpass` (required for password-based SSH to the router)

```bash
sudo apt install sshpass
ansible-galaxy collection install -r requirements.yml
ansible-galaxy role install -r requirements.yml
```

Galaxy roles install to `~/.ansible/roles` (global, not committed).
Project roles live in `playbooks/roles/`.

---

## Network topology

```
Internet
    │
    │ WAN (DHCP from ISP)
    │
┌───┴─────────────────────────────────────┐
│  router (Cudy WR3000S)  10.10.10.1      │
│  OpenWrt 25.12.4                        │
│  DNS: unbound (127.0.0.1:5335)          │
│       dnsmasq → unbound → DoT           │
│       upstreams: Cloudflare + Google    │
│  adblock-fast (dnsmasq.servers)         │
│  step-ca       :8443  (ACME CA, native)  │
└───┬─────────────────┬───────────────────┘
    │ LAN             │ IoT
    │ 10.10.10.0/24   │ 10.10.30.0/24
    │                 │ (isolated, WAN only)
    │
    ├── lab1  10.10.10.10  (MAC 70:85:c2:63:58:5b)
    │   Debian/Ubuntu Server
    │   Docker host
    │   ├── traefik        :80/:443
    │   │   └── traefik.lab1.lan  (dashboard)
    │   ├── postgres       :5432
    │   │   └── db.lan
    │   ├── meilisearch    :7700 (internal, for linkwarden)
    │   ├── kopia server   :51514 (native)
    │   ├── kopia agent    (native)
    │   ├── dockhand agent (Hawser, connects to dockhand.lan)
    │   ├── dbgate         (via Traefik)
    │   │   └── db.lan
    │   ├── qbittorrent    (via Traefik)
    │   │   └── qbit.lab1.lan
    │   ├── vaultwarden    (via Traefik)
    │   │   └── vw.lan
    │   ├── linkwarden     (via Traefik)
    │   │   └── links.lan
    │   └── immich         (via Traefik)
    │       └── photos.lan
    │
    └── lab2  10.10.10.11  (MAC 2c:56:dc:7b:69:d1)
        Debian/Ubuntu Server
        Docker host
        ├── traefik        :80/:443
        │   └── traefik.lab2.lan  (dashboard)
        ├── homepage       (via Traefik)
        │   └── home.lan
        ├── dockhand       (via Traefik)
        │   └── dockhand.lan
        ├── kopia agent    (native)
        ├── cyberchef      (via Traefik)
        │   └── chef.tools.lan
        ├── it-tools       (via Traefik)
        │   └── it.tools.lan
        ├── searxng        (via Traefik)
        │   └── search.lan
        ├── qbittorrent    (via Traefik)
        │   └── qbit.lab2.lan
        └── inpx-web       (via Traefik)
            └── lib.lan

Wi-Fi:
  Main (2.4 + 5 GHz, WPA3/WPA2, hidden) → LAN
  IoT  (2.4 GHz, WPA2)                  → IoT

DNS (*.lan resolved by dnsmasq):
  lab1.lan            → 10.10.10.10  (DHCP reservation by MAC)
  lab2.lan            → 10.10.10.11  (DHCP reservation by MAC)
  step-ca.lan         → openwrt.lan  (CNAME)
  traefik.lab1.lan    → lab1.lan     (CNAME)
  traefik.lab2.lan    → lab2.lan     (CNAME)
  home.lan            → lab2.lan     (CNAME)
  dockhand.lan        → lab2.lan     (CNAME)
  vw.lan              → lab1.lan     (CNAME)
  qbit.lab1.lan       → lab1.lan     (CNAME)
  qbit.lab2.lan       → lab2.lan     (CNAME)
  lib.lan             → lab2.lan     (CNAME)
  db.lan              → lab1.lan     (CNAME)
  links.lan           → lab1.lan     (CNAME)

  chef.tools.lan      → lab2.lan     (CNAME)
  it.tools.lan        → lab2.lan     (CNAME)
  photos.lan          → lab1.lan     (CNAME)
  search.lan          → lab2.lan     (CNAME)
```

---

## Manual setup — do these in order

These are one-time steps that must be done by hand. Ansible assumes they are already complete before it runs.

### 1. Router — set root password

```bash
ssh root@192.168.1.1
passwd
```

### 2. Router — change LAN IP to 10.10.10.1

```bash
uci set network.lan.ipaddr='10.10.10.1'
uci commit network
service network restart
```

> On OpenWrt 25.12+, `network.lan.ipaddr` requires CIDR notation: `10.10.10.1/24`

Your SSH session will drop. Reconnect:

```bash
ssh root@10.10.10.1
```

### 3. Vault — add all secrets

```bash
ansible-vault edit vault/secrets.yml
```

Add all required variables — see the [Vault](#vault) section for the full list.

### 4. Run site playbook

```bash
ansible-playbook playbooks/site.yml
```

This runs both plays: router (OpenWrt configuration) and servers (step-ca init, all services). You can also run them separately:

```bash
ansible-playbook playbooks/site.yml --tags router    # router only
ansible-playbook playbooks/site.yml --tags servers   # servers only
```

> The router play does not support `--check` mode.

### 5. Install root CA on your devices

Open `http://openwrt.lan/ca.html` in your browser — it contains the root certificate for download and step-by-step installation instructions for your platform.

Do this once per device. After this, all `*.lan` HTTPS services will show a green padlock with no warnings.

---

## Vault

Secrets live in `vault/secrets.yml`. Encrypt before committing:

```bash
ansible-vault encrypt vault/secrets.yml
```

Store the vault password in `.vault_pass` (gitignored) for passwordless runs:

```bash
echo "your-vault-password" > .vault_pass && chmod 600 .vault_pass
```

See [`vault/secrets.example.yml`](vault/secrets.example.yml) for the full list of required variables, ordered by playbook execution.

---

## Running playbooks

```bash
# Everything (router + servers)
ansible-playbook playbooks/site.yml

# By layer
ansible-playbook playbooks/site.yml --tags layer_barebone
ansible-playbook playbooks/site.yml --tags layer_os_services
ansible-playbook playbooks/site.yml --tags layer_shared
ansible-playbook playbooks/site.yml --tags layer_platform
ansible-playbook playbooks/site.yml --tags layer_tools
ansible-playbook playbooks/site.yml --tags layer_home

# Single service
ansible-playbook playbooks/site.yml --tags traefik
ansible-playbook playbooks/site.yml --tags dockhand,dockhand_agent

# Limit to specific host
ansible-playbook playbooks/site.yml --limit lab2

# Router only
ansible-playbook playbooks/site.yml --tags router

# Servers only (use --limit instead)
ansible-playbook playbooks/site.yml --limit lab1
```

Add `--ask-vault-pass` if not using `.vault_pass`.

The router play does not support `--check` mode.

---

## Locale

Each server generates and activates three locales: `en_US.UTF-8`, `en_DK.UTF-8`, `ru_RU.UTF-8`.

`en_DK.UTF-8` is used as `LANG` — it's English language with ISO 8601 conventions (YYYY-MM-DD dates, 24h clock, dot decimal separator, Monday-first weeks). Denmark locale is the traditional Linux choice for "international English" — same as `en_US` for language, but sane date/number formats.

`LC_MESSAGES` is pinned to `en_US.UTF-8` because `en_DK` message catalogs are sparse and some tools fall back to untranslated output.

`LC_COLLATE` and `LC_CTYPE` use `ru_RU.UTF-8` so Cyrillic filenames (e.g. book archives) sort alphabetically rather than by raw Unicode codepoint.

```
LANG=en_DK.UTF-8        # ISO dates/numbers, English language
LC_MESSAGES=en_US.UTF-8 # guaranteed English tool output
LC_COLLATE=ru_RU.UTF-8  # Cyrillic sorts alphabetically
LC_CTYPE=ru_RU.UTF-8    # Cyrillic recognized as valid letters
```

---

## Adding a service

### To an existing lab

1. Add the host to the service's inventory group in `inventory/hosts.yml`
2. Run `ansible-playbook playbooks/site.yml`

### New service

1. Create `playbooks/roles/<layer>/<name>/` with `tasks/main.yml`, `handlers/main.yml`, `defaults/main.yml`
2. Add CNAME registration using `include_role: common_tasks` with `tasks_from: register_cname`
3. Add a group under `children` in `inventory/hosts.yml`
4. Add the role to `site.yml` with appropriate `when:` guard and layer tag
5. Add any secrets to `vault/secrets.yml` and vars to `inventory/group_vars/servers.yml`
6. Run `ansible-playbook playbooks/site.yml --tags <service>`

Minimal Traefik labels for a new container:

```yaml
labels:
  traefik.enable: "true"
  traefik.http.routers.myapp.rule: "Host(`myapp.lan`)"
  traefik.http.routers.myapp.entrypoints: "websecure"
  traefik.http.routers.myapp.tls: "true"
  traefik.http.routers.myapp.tls.certresolver: "step-ca"
  traefik.http.services.myapp.loadbalancer.server.port: "8080"
```

Homepage auto-discovery labels (add alongside Traefik labels):

```yaml
  homepage.group: "Apps"
  homepage.name: "MyApp"
  homepage.icon: "sh-myapp"
  homepage.href: "https://myapp.lan"
  homepage.description: "Short description"
```

---

## Troubleshooting

**`DNS_PROBE_FINISHED_NXDOMAIN` for `*.lan` in Chrome/Edge**

Chromium-based browsers have a "Use secure DNS" (DoH) setting that bypasses the system resolver and sends queries to a public DNS provider, which has no knowledge of your local `.lan` domain.

Disable it: `chrome://settings/security` → "Use secure DNS" → off. Same for Edge: `edge://settings/privacy` → "Use secure DNS" → off.

**ACME cert not issuing / Traefik serving default cert**

step-ca (on the router) needs to reach the Traefik host on port 443 to complete the TLS-ALPN-01 challenge. Make sure:

- Port 443 is reachable on the Traefik host from the router
- `acme.json` has `600` permissions — if corrupt, delete it and restart Traefik

**DockHand agent (Hawser) not reachable**

Hawser on lab1 connects to DockHand on lab2 via HTTP on port 2376. Ensure:

- Hawser container is healthy (`docker ps`)
- Port `2376` is reachable from lab2 (`curl http://lab1.lan:2376/_hawser/health`)
- CA cert is installed on lab1 (`update-ca-certificates --fresh`)

**Verify DNS-over-TLS is working**

On the router:

```bash
# Should show ESTABLISHED connections to port 853
netstat -n | grep 853

# Should resolve without errors
drill @127.0.0.1 -p 5335 google.com
```
