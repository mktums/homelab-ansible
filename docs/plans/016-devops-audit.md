# DevOps Audit — Homelab Ansible

Brutal review of the entire project. Issues sorted by severity
(CRITICAL > HIGH > MEDIUM > LOW).

| # | Short description | Long Description | Decision |
|---|---|---|---|
| 1 | Mutable image tags | `vaultwarden:latest`, `linkwarden:latest`, `traefik:v3`, `immich:release`, `dbgate:latest` — any can silently break or introduce CVEs on next pull. Pin to version tags (e.g., `v3.2`, `17-alpine`), not `latest`. DockHand handles update detection. | ✅ To fix |
| 2 | Postgres exposed on 0.0.0.0 | `postgres/docker-compose.yml.j2` binds port 5432 to all interfaces. Every LAN host can connect directly. Bind to `127.0.0.1` or use Docker networking with no port mapping. | ❌ Rejected — LAN is trusted, services need cross-host access |
| 3 | DockHand agent: write Docker socket | `dockhand_agent/docker-compose.yml.j2` mounts docker.sock without `:ro`. Container escape = full root on host. Traefik does it correctly with `:ro`. | ❌ Rejected — DockHand needs write access to manage containers |
| 4 | DBGate stores Postgres superuser password | `dbgate/templates/.env.j2` uses `{{ postgres_password }}` (root DB password) instead of a limited-service credential. Mitigated by `mode: "0600"` on the .env file — only root can read it. | ❌ Rejected — file is `0600`, only root can read |
| 5 | Linkwarden SSRF enabled | `ALLOW_PRIVATE_NETWORK_ACCESS=true` allows SSRF to internal addresses, metadata services (`169.254.169.254`), and internal admin panels. | ❌ Rejected — Linkwarden will be replaced with ArchiveBox |
| 6 | Binaries downloaded without checksums | step-ca and kopia binaries downloaded from `latest/` URLs with no hash verification. Compromised release = backdoored binaries with no detection. | ✅ To fix — pin versions + add checksum verification |
| 7 | CA cert fetch skips TLS validation | `step_cli/tasks/main.yml` fetches root CA with `validate_certs: false`. Chicken-and-egg: can't validate TLS to the CA before trusting the CA. Fingerprint check provides actual security. | ⚠️ Note — find a proper way to get fingerprint without MITM risk |
| 8 | Kopia password in logs | `kopia_server/tasks/deploy.yml` has `no_log: true` commented out on repo init. `KOPIA_PASSWORD` env var leaks to task output. Same on multiple kopia CLI commands. | ✅ To fix |
| 9 | Unattended upgrades on servers | `security_autoupdate_enabled: true` only enables `unattended-upgrades` for the security repo (`*-security`), not all packages. `security_autoupdate_reboot: false` prevents auto-reboot. Only risk: kernel security update + NVIDIA DKMS rebuild on next manual reboot. | ❌ Rejected — security-only, no auto-reboot |
| 10 | Docker group = root equivalent | Adding `admin_user` to docker group grants effective root. User already has sudo access, so this is just a convenience for running `docker` without `sudo docker`. | ❌ Rejected — user already has sudo |
| 11 | `pull: missing` never updates images | Every `docker_compose_v2` uses `pull: missing` — "pull if absent locally." Intentional: DockHand handles update detection. Once #1 pins to version tags, `pull: missing` is correct behavior. | ❌ Rejected — resolved by #1 |
| 12 | `create_pg_database` swallows failures | `failed_when: false` on `CREATE DATABASE` hides all errors — auth failures, network issues, disk full — not just the expected "already exists" case. | ✅ Fixed — check for "already exists" in stderr |
| 13 | kopia_agent meta depends on kopia_server | Agent role declares server role as dependency. Ensures `--tags kopia_agent` still deploys server first. Server defaults (`kopia_cname`, `kopia_internal_port`) are available to agent. `when` guard prevents execution on non-server hosts. | ❌ Rejected — intentional for ordering + variable availability |
| 14 | `kopia_server_host` assumes list order | `groups['kopia_server_hosts'][0]` assumes stable inventory order. Only one kopia server (lab1), inventory is stable. | ❌ Rejected — single server, stable inventory |
| 15 | DockHand API calls delegate to localhost | `register_dockhand_env.yml` delegates all API calls to `localhost` (Windows controller). Controller can reach lab network. | ❌ Rejected — controller has network access |
| 16 | `evaluate=True` in `regex_search` | `tuning.yml:215` uses `evaluate=True` in `regex_search` — not a valid parameter per docs. May be silently ignored or cause errors. Fix: use `\\1` for capture groups. | ✅ To fix |
| 17 | bash-completion installed twice | `packages.yml` installs via `common_packages` apt list, then again via separate `ansible.builtin.package` task. | ✅ Fixed — removed from `common_packages` list |
| 18 | `gather_facts: false` then manual setup | `site.yml` sets `gather_facts: false` then immediately calls `ansible.builtin.setup` in pre_tasks. | ✅ Fixed — set `gather_facts: true` on servers play |
| 19 | `changed_when: false` overuse | Dozens of tasks use `changed_when: false` on operations that clearly change state (kopia policy set, maintenance set, etc.). Ansible reports lie — "0 changed" despite real work. | ⚠️ To investigate — large scope, affects many tasks |
| 20 | `container_name` breaks Compose semantics | `arr_stack`, `dockhand`, `dockhand_agent`, `immich` use `container_name`. Prevents scaling, breaks `--force-recreate`, causes name collisions on manual compose runs. | ✅ Fixed — removed from all compose files |
| 21 | `/etc/localtime` mount instead of TZ | Every compose file mounts `/etc/localtime:/etc/localtime:ro`. Modern approach is `TZ` env var. Not all images support TZ, so keeping both is safest. | ❌ Rejected — keep both for compatibility |
| 22 | Traefik `network_mode: host` | Host network mode gives direct access to all host ports, bypasses Docker DNS, and prevents Compose service discovery. Valid pattern for single reverse proxy. | ❌ Rejected — valid pattern for homelab proxy |
| 23 | `groups.get()` on Ansible inventory | `site.yml` uses Python dict `.get()` method on `groups`. `groups['key'] \| default([])` would raise KeyError on missing key. `.get()` is correct here. | ❌ Rejected — `.get()` is correct |
| 24 | adblock-lean from raw GitHub URL | Downloaded from `raw.githubusercontent.com` with no hash or version pin. Compromised repo = compromised router DNS. | ✅ To fix — pin version + add checksum verification |
| 25 | Unbound DoT forwarders hardcoded | Hardcoded to Cloudflare + Google. In Russia, both may be throttled or monitored. | ✅ Fixed — added Quad9 |
| 26 | step-ca wildcard `*.lan` policy | Wildcard cert policy means a single compromised CA private key (stored on every server) validates every LAN service. Per-service certs limit blast radius. | ✅ To fix |
| 27 | Kopia reuses same password | Repo creation, user passwords, and control RPC all use same or closely-related secrets. It's the repo encryption password - all operations against that repo must use it. | ❌ Rejected — how Kopia works |
| 28 | ACME email is unreachable | `traefik_acme_email: "admin@lan"` — no one receives cert expiry warnings. No SMTP set up anyway. | ❌ Rejected — no SMTP, formality only |
| 29 | Commented-out roles in site.yml | Jellyfin and arr_stack are commented out in the main playbook. | ✅ Fixed — uncommented jellyfin, arr_stack kept disabled |
| 30 | `ansible_ssh_transfer_method` conflict | `piped` + `ansible_scp_if_ssh: true` can conflict depending on Ansible version. | ✅ Fixed — removed `ansible_scp_if_ssh`, kept `piped` for router only |
| 31 | `ansible_python_interpreter: none` | Router-only setting. `gather_facts: false` in play, `community.openwrt` has its own fact gathering. | ❌ Rejected — router-only, works fine |
| 32 | TLD-less domain `.lan` | Some tools and browsers have issues with TLD-less domains. `.local` is reserved for mDNS (RFC 6762). `.lan` is fine for homelab. | ❌ Rejected — `.local` is mDNS, `.lan` is fine |
| 33 | SSH port explicitly kept at 22 | `security_ssh_port: 22` keeps default port. Role handles it fine, no real issue. | ❌ Rejected — minor, role handles it fine |
| 34 | `community.openwrt` collection risk | Third-party collection, less maintained than core modules. Only Ansible collection for OpenWrt, no alternative. | ❌ Rejected — no alternative |
| 35 | `flush_handlers` in adblock role | Manual `flush_handlers` to ensure dnsmasq restarts before adblock-lean starts. Valid Ansible pattern. | ❌ Rejected — valid pattern |
| 36 | `report_hw.sh` is 680 lines of bash | Comprehensive but extremely long. May rewrite later. | ❌ Rejected — works fine |
| 37 | Legacy `action:` keyword | Uses `action: "community.openwrt.{{ openwrt_package_manager }}"` for dynamic module selection. `action:` is correct for this pattern. | ❌ Rejected — `action:` is correct for dynamic modules |
| 38 | `raw` module in adblock handler | `openwrt_adblock/handlers/main.yml` uses `ansible.builtin.raw` while rest of role uses `community.openwrt.command`. | ✅ Fixed — replaced with `community.openwrt.command` |
| 39 | No ansible-lint or CI | No linting, no syntax checking CI, no molecule tests. May add molecule later. | ❌ Rejected — manual debug for now |
| 40 | `failed_when: false` hides real errors | Used on `swapon --show`, `dpkg-query`, and other diagnostic commands. Real failures are silently ignored. | ⚠️ To investigate — large scope, affects many tasks |
| 41 | Ansible outdated | Running ansible 13.4.0 (Feb 2026). Latest is 14.1.0 (Jun 2026). ~4 months behind. Update `ansible` and `ansible-core` packages. | ✅ To fix |
