# Add Immich

**Priority:** Normal
**Difficulty:** Medium (11 new files, 5 modified)
**Status:** Planned

## Summary

Add Immich — self-hosted photo/video management with ML-powered search, facial recognition, and video transcoding. Deployed on lab1 (Furnace) which has the CPU, RAM, and GPU to handle the ML workload.

## Decisions

| Decision | Value | Rationale |
|---|---|---|
| Host | lab1 | 8C/16T, 32GB RAM, RTX 2080 SUPER — lab2 (2C/2T, 8GB) can't handle ML |
| Database | Bundled Postgres | Immich's custom tuning (vchord, autovacuum, IO concurrency); upgrade compatibility |
| Redis | Bundled Valkey | No other service needs Redis yet; lightweight (~10MB RAM) |
| ML acceleration | CUDA | RTX 2080 SUPER (CC 7.5, 8GB VRAM); nvidia-container-toolkit already installed |
| Video transcoding | NVENC | Offloads from CPU; GPU has dedicated encoder blocks |
| UPLOAD_LOCATION | `/mnt/data/immich` | 3TB WD Red, 99% free; photos/videos are bulk data |
| DB_DATA_LOCATION | `/srv/docker_data/immich/postgres` | NVMe; Immich's SSD tuning (`effective_io_concurrency=200`) |
| CNAME | `photos` | Clear, short |
| Config file | JSON, Ansible-managed | Set concurrency for 4C/8T (leaving headroom for 2 PGs + other services), disable built-in backup |
| Storage template | On | Date-based organization: `library/<userID>/{{y}}/{{y}}-{{MM}}-{{dd}}/` |
| Backup | pg_dump pre-backup + Kopia | Consistent DB snapshots without downtime; Kopia handles dedup + retention |
| SMTP | Later | Not critical for initial deploy |
| OAuth | Later | No IdP deployed yet |

## Files to create

### Role: `playbooks/roles/docker_services/apps/immich/`

- `defaults/main.yml` — image names/tags, paths, CNAME
- `handlers/main.yml` — restart handler
- `meta/main.yml` — dependency: `traefik` only
- `tasks/main.yml` — includes cname.yml, deploy.yml, backup.yml
- `tasks/cname.yml` — register `photos.{{ lan_domain }}`
- `tasks/deploy.yml` — create dirs, render compose + config + .env, deploy via `docker_compose_v2`
- `tasks/backup.yml` — install pg_dump script + systemd timer
- `templates/docker-compose.yml.j2` — 4 services (server, ML, redis, postgres), inlined NVENC + CUDA hwaccel
- `templates/immich-config.json.j2` — storage template on, backup disabled, concurrency tuned for 4C/8T
- `templates/pg_dump.sh.j2` — pg_dumpall → gzip → `UPLOAD_LOCATION/backups/`, keeps last 14

## Files to modify

- `inventory/hosts.yml` — add `immich_hosts` group with `lab1`
- `playbooks/site.yml` — add immich role in 3d: Apps section
- `inventory/group_vars/servers.yml` — add `immich_db_password`
- `vault/secrets.example.yml` — add `vault_immich_db_password`
- `README.md` — add to network topology (lab1) and DNS section

## Concurrency targets (4C/8T, leaving headroom)

Tuned conservatively — lab1 also runs 2 Postgres instances, Traefik, kopia_agent, beszel_agent, qbittorrent, vaultwarden, linkwarden, and dockhand_agent.

| Job | Concurrency |
|---|---|
| thumbnailGeneration | 3 |
| videoConversion | 1 |
| smartSearch | 2 |
| faceDetection | 2 |
| metadataExtraction | 3 |
| migration | 3 |
| library | 3 |
| backgroundTask | 3 |
| notifications | 3 |
| sidecar | 3 |
| ocr | 1 |
| search | 3 |

## Post-deploy

After first deploy, create admin account via `https://photos.{{ lan_domain }}` (Immich shows onboarding screen). No `[POST-DEPLOY]` secrets needed — admin is created through the web UI.
