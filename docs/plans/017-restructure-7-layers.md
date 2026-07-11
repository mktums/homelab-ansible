# 017: Restructure roles into 7-layer model

## Status

✅ Done (2026-07-05)

## Motivation

Current layer 3 (`docker_services/`) is a catch-all for all Docker-based roles with sub-categories (`infra/`, `shared/`, `tools/`, `apps/`). The sub-categories don't reflect deployment dependencies clearly, and the flat `docker_services` namespace makes the directory tree harder to traverse mentally.

Restructure into 7 layers that reflect both deployment order and conceptual purpose.

## Target layer model

| Layer | Dir | Tag | Contents |
|-------|-----|-----|----------|
| 1 | `barebone/` | `layer_barebone` | OS setup, users, configs |
| 2 | `os_services/` | `layer_os_services` | Docker, kopia, step_cli, step-ca |
| 3 | `shared/` | `layer_shared` | traefik, postgres, meilisearch |
| 4 | `platform/` | `layer_platform` | beszel_hub, beszel_agent, dockhand, dockhand_agent |
| 5 | `tools/` | `layer_tools` | cyberchef, it_tools, dbgate |
| 6 | `home/` | `layer_home` | vaultwarden, qbittorrent, inpx_web, linkwarden, immich, jellyfin, arr_stack, homepage |
| 7 | `dev/` | `layer_dev` | *(empty — future dev services)* |

## Design decisions

- **`shared/`** — traefik + databases form the foundational layer. Layers 4-7 can depend on them, but are not obliged to. Traefik moved from `infra/` because it's a shared dependency, not a "platform tool".
- **`platform/`** — monitoring, alerting, observability. Beszel and dockhand manage/observe the platform.
- **`tools/`** — utility/admin services by function scope. Reimagined from "stateless" to "utility and admin interfaces". Dbgate belongs here.
- **`home/`** — user-facing home services. Homepage moved here as the home dashboard.
- **`dev/`** — reserved for future dev services (forgejo, weblate, dev homepage). Empty now. Dev databases will go to `shared/` (layer 3). Created for clarity of purpose and directory traversal sanity.
- **Layers 4-7 are independent** — no cross-dependencies between them.
- **No umbrella tag** — removed `docker_services` tag. Only layer tags + per-service tags remain.
- **`arr_stack`** — moved to `home/`, kept commented out in site.yml.
- **`beszel_hub` + `beszel_agent`** — same layer (`platform/`). Intra-layer dependency handled by meta.

## Changes

### 1. Move directories (18 moves, `git mv`)

| From | To |
|------|-----|
| `docker_services/infra/traefik` | `shared/traefik` |
| `docker_services/shared/postgres` | `shared/postgres` |
| `docker_services/shared/meilisearch` | `shared/meilisearch` |
| `docker_services/infra/beszel_hub` | `platform/beszel_hub` |
| `docker_services/infra/beszel_agent` | `platform/beszel_agent` |
| `docker_services/infra/dockhand` | `platform/dockhand` |
| `docker_services/infra/dockhand_agent` | `platform/dockhand_agent` |
| `docker_services/tools/cyberchef` | `tools/cyberchef` |
| `docker_services/tools/it_tools` | `tools/it_tools` |
| `docker_services/apps/dbgate` | `tools/dbgate` |
| `docker_services/apps/vaultwarden` | `home/vaultwarden` |
| `docker_services/apps/qbittorrent` | `home/qbittorrent` |
| `docker_services/apps/inpx_web` | `home/inpx_web` |
| `docker_services/apps/linkwarden` | `home/linkwarden` |
| `docker_services/apps/immich` | `home/immich` |
| `docker_services/apps/jellyfin` | `home/jellyfin` |
| `docker_services/apps/arr_stack` | `home/arr_stack` |
| `docker_services/infra/homepage` | `home/homepage` |

Remove `docker_services/` directory after all moves.

### 2. Update meta/main.yml (16 files)

All `docker_services/...` role paths → new paths:

| Role | Old dependency → New |
|------|-----------|
| `shared/traefik` | *(no change — depends on `os_services/step_cli`)* |
| `platform/beszel_hub` | `docker_services/infra/traefik` → `shared/traefik` |
| `platform/beszel_agent` | `docker_services/infra/beszel_hub` → `platform/beszel_hub` |
| `platform/dockhand` | `docker_services/infra/traefik` → `shared/traefik`, `docker_services/shared/postgres` → `shared/postgres` |
| `tools/cyberchef` | `docker_services/infra/traefik` → `shared/traefik` |
| `tools/it_tools` | `docker_services/infra/traefik` → `shared/traefik` |
| `tools/dbgate` | `docker_services/infra/traefik` → `shared/traefik` |
| `home/vaultwarden` | `docker_services/infra/traefik` → `shared/traefik`, `docker_services/shared/postgres` → `shared/postgres` |
| `home/linkwarden` | `docker_services/infra/traefik` → `shared/traefik`, `docker_services/shared/postgres` → `shared/postgres`, `docker_services/shared/meilisearch` → `shared/meilisearch` |
| `home/arr_stack` | `docker_services/infra/traefik` → `shared/traefik`, `docker_services/shared/postgres` → `shared/postgres` |
| `home/immich` | `docker_services/infra/traefik` → `shared/traefik` |
| `home/jellyfin` | `docker_services/infra/traefik` → `shared/traefik` |
| `home/qbittorrent` | `docker_services/infra/traefik` → `shared/traefik` |
| `home/inpx_web` | `docker_services/infra/traefik` → `shared/traefik` |
| `home/homepage` | `docker_services/infra/traefik` → `shared/traefik` |

### 3. Update site.yml

- Rewrite all 18 role paths to match new directory structure
- Replace tags: `layer_docker_shared` → `layer_shared`, `layer_docker_infra` → `layer_platform`, `layer_docker_tools` → `layer_tools`, `layer_docker_apps` → `layer_home`
- Remove `docker_services` tag from all roles
- Restructure sections: Layer 3 (shared) → Layer 4 (platform) → Layer 5 (tools) → Layer 6 (home) → Layer 7 (dev)
- Each layer section gets a comment describing its purpose and where to find roles that belong to it
- Update header comments with new 7-layer model and tag usage examples
- Keep `arr_stack` commented out

### 4. Update ansible.cfg

Replace `roles_path`:

```ini
roles_path = ~/.ansible/roles:playbooks/roles:playbooks/roles/barebone:playbooks/roles/os_services:playbooks/roles/shared:playbooks/roles/platform:playbooks/roles/tools:playbooks/roles/home:playbooks/roles/dev
```

### 5. Update README.md

- "New service" section: `docker_services/<category>/<name>/` → `<layer>/<name>/`

### 6. Create empty dev directory

```
playbooks/roles/dev/
```

### 7. Verify

Run `ansible-playbook --list-tasks playbooks/site.yml` manually to confirm all role paths resolve.

## Execution order

1. Move directories (`git mv`) — preserves history
2. Update meta/main.yml files — dependency paths
3. Update site.yml — role paths, tags, comments
4. Update ansible.cfg — roles_path
5. Update README.md
6. Create empty `dev/` directory
7. Verify with ansible dry-run

## Risk assessment

- **Low risk** — pure restructuring, no logic or behavior changes
- Meta dependencies are the critical path — wrong paths cause Ansible role resolution failure
- `--list-tasks` dry run catches unresolved paths before any actual execution

## Affected files

| File | Change |
|------|--------|
| `ansible.cfg` | `roles_path` |
| `playbooks/site.yml` | role paths, tags, comments |
| `playbooks/roles/shared/traefik/` | moved |
| `playbooks/roles/shared/postgres/` | moved |
| `playbooks/roles/shared/meilisearch/` | moved |
| `playbooks/roles/platform/beszel_hub/` | moved, meta updated |
| `playbooks/roles/platform/beszel_agent/` | moved, meta updated |
| `playbooks/roles/platform/dockhand/` | moved, meta updated |
| `playbooks/roles/platform/dockhand_agent/` | moved |
| `playbooks/roles/tools/cyberchef/` | moved, meta updated |
| `playbooks/roles/tools/it_tools/` | moved, meta updated |
| `playbooks/roles/tools/dbgate/` | moved, meta updated |
| `playbooks/roles/home/vaultwarden/` | moved, meta updated |
| `playbooks/roles/home/qbittorrent/` | moved, meta updated |
| `playbooks/roles/home/inpx_web/` | moved, meta updated |
| `playbooks/roles/home/linkwarden/` | moved, meta updated |
| `playbooks/roles/home/immich/` | moved, meta updated |
| `playbooks/roles/home/jellyfin/` | moved, meta updated |
| `playbooks/roles/home/arr_stack/` | moved, meta updated |
| `playbooks/roles/home/homepage/` | moved, meta updated |
| `playbooks/roles/dev/` | **new** — empty directory |
| `playbooks/roles/docker_services/` | **removed** |
| `README.md` | path reference update |

