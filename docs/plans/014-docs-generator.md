# 014: Documentation Generator

## Overview

Build a Python-based documentation generator that reads Ansible YAML files and role metadata, then renders Jinja2 templates into comprehensive markdown documentation. Replaces the outdated approach proposed in [006](006-docs-generator-approach.md).

## Approach

Single generator script (`scripts/gen_docs.py`) with two phases:

1. **Gather facts** - reads local YAML files, builds structured data dict
2. **Render** - feeds facts to Jinja2 templates, outputs markdown

No Ansible execution required for static docs. Hardware reports collected separately via playbook.

## Sources

| Source | Extracted Data |
|--------|---------------|
| `playbooks/roles/**/defaults/main.yml` | cname, image, port, data_dir, config_dir |
| `playbooks/roles/**/meta/main.yml` | role dependencies |
| `playbooks/roles/**/templates/docker-compose.yml.j2` | volumes, ports, labels, env, restart policy, healthcheck, network_mode |
| `inventory/hosts.yml` | hosts per role (via `<role>_hosts` groups) |
| `inventory/group_vars/all.yml` | lan_domain, lan_dns |
| `inventory/group_vars/routers.yml` | network segments, DHCP, Wi-Fi, port forwards |
| `inventory/host_vars/*.yml` | backup_sources, per-host overrides |
| `vault/secrets.example.yml` | secret names, descriptions, [GENERATED]/[POST-DEPLOY] flags, generate hints |
| `docs/meta.yml` | description, why, alternatives per role |
| `docs/hw_reports/*.json` | hardware data (from `collect_hw.sh`) |

Role path to category/layer mapping:
- `barebone/*` -> layer_barebone
- `os_services/*` -> layer_os_services
- `docker_services/infra/*` -> docker_services_infra, category=infra
- `docker_services/tools/*` -> docker_services_tools, category=tools
- `docker_services/shared/*` -> docker_services_shared, category=shared
- `docker_services/apps/*` -> docker_services_apps, category=apps

Variable resolution: simple `{{ var }}` substitution for known base vars (`ansible_opt_base`, `docker_data_base`, `srv_base`, `lan_domain`). Complex expressions remain as-is.

## Prerequisites

- `just` — standalone binary (not a Python package, install via package manager or [just.systems](https://just.systems))
- `pre-commit` — Python package (`pip install pre-commit`), run `pre-commit install` to hook into git

## New Files

| File | Purpose |
|------|---------|
| `requirements.txt` | Python deps: `pyyaml`, `jinja2` |
| `justfile` | Build targets: `docs`, `docs-check`, `hw` |
| `.pre-commit-config.yaml` | Pre-commit hook config (triggered by `pre-commit run` on `git commit`) |
| `docs/meta.yml` | Role metadata (description, why, alternatives) |
| `scripts/gen_docs.py` | Main generator (gather facts, render templates) |
| `scripts/collect_hw.sh` | Hardware collector -> JSON output |
| `docs/templates/**/*.md.j2` | 24 Jinja2 templates |

## Renamed

| From | To |
|------|-----|
| `scripts/hw_report.sh` | `scripts/report_hw.sh` |

## Modified

| File | Change |
|------|--------|
| `playbooks/collect_hw.yml` | Update `script_src` path: `hw_report.sh` -> `report_hw.sh` |

## Template Structure

24 templates total under `docs/templates/`. Rendered output mirrors structure under `docs/`.

- `index.md.j2`
- `architecture/overview.md.j2`, `network-topology.md.j2`, `infrastructure.md.j2`, `services-map.md.j2`
- `services/_generic.md.j2` (fallback; per-service override possible)
- `operations/backups.md.j2`, `updates.md.j2`, `migrations.md.j2`, `certificates.md.j2`, `monitoring.md.j2`
- `troubleshooting.md.j2`
- `development/ansible-overview.md.j2`, `adding-services.md.j2`, `roles-explained.md.j2`, `inventory-guide.md.j2`
- `reference/vault-secrets.md.j2`, `host-vars.md.j2`, `group-vars.md.j2`, `commands.md.j2`
- `decisions/service-choices.md.j2`, `infrastructure.md.j2`, `faq.md.j2`
- `future/watchlist.md.j2`, `comparisons.md.j2`, `notes.md.j2`

## `docs/meta.yml` Format

Key matches role directory name. Category and layer derived from role path.

```yaml
roles:
  traefik:
    description: "Reverse proxy with automatic TLS termination"
    why: "Dynamic service discovery via Docker labels, native ACME support"
    alternatives: "Caddy, Nginx Proxy Manager"
    open_to_alternatives: true
```

## `justfile` Targets

```
docs:
    python3 scripts/gen_docs.py

docs-check:
    python3 scripts/gen_docs.py --check

hw:
    ansible-playbook playbooks/collect_hw.yml
```

## Pre-commit Hook

Runs `just docs` on every commit. Regenerates all docs from templates.

## Secrets Reference

Parser extracts from `secrets.example.yml`:
- Section headers (e.g., `# -- Traefik --`)
- Variable names (`vault_*: ""`)
- Description comments (lines above variable)
- Flags (`[GENERATED]`, `[POST-DEPLOY]`)
- Generate hints (`# Generate: openssl rand -hex 32`)

Template renders grouped table per section.

## Hardware Collection

`scripts/collect_hw.sh` - new script, same data as `report_hw.sh` but outputs JSON. `collect_hw.yml` fetches to `docs/hw_reports/<host>.json`. Generator reads JSON for `infrastructure.md`.

`scripts/report_hw.sh` - renamed from `hw_report.sh`, kept alongside during transition.

## Implementation Steps

1. Install prerequisites: `just` (binary), `pre-commit` (pip)
2. Create `requirements.txt`, install Python deps
3. Create `justfile`, `.pre-commit-config.yaml`, run `pre-commit install`
3. Rename `scripts/hw_report.sh` -> `scripts/report_hw.sh`, update `collect_hw.yml`
4. Create `docs/meta.yml` with entries for all current roles
5. Create `scripts/gen_docs.py` (facts gathering + rendering)
6. Create `scripts/collect_hw.sh` (JSON output)
7. Create all 24 Jinja2 templates under `docs/templates/`
8. Run `just docs`, verify output
9. Test `just docs-check` and pre-commit hook

## Difficulty

Hard - many files, cross-cutting concerns, new tooling.

## Priority

Normal

## Status

Planned
