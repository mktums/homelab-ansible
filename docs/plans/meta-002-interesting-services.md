# meta-002: Interesting Services

## Status

Living document

## Purpose

Catalog of interesting services — from definite candidates to far-fetched wishlist items. Each entry captures what the service does, which layer it belongs in, and what would be needed to deploy it.

## Format

Each entry:

| Field | Description |
|-------|-------------|
| **Service** | Name, short description |
| **Layer** | Which of the 7 layers it belongs in |
| **Priority** | `high` / `medium` / `low` / `wishlist` |
| **Dependencies** | What must exist first (traefik, postgres, etc.) |
| **Effort** | `easy` (1 role, no DB) / `medium` (DB or multi-container) / `hard` (custom config, native binary) |
| **Notes** | Blockers, alternatives, configuration considerations |

## Entries

### Forgejo

Lightweight Git server with issue tracking, CI/CD, and package registry. Active fork of Gitea.

<https://forgejo.org/docs/latest/>

- **Layer**: 7 (dev) — development services
- **Priority**: `medium`
- **Dependencies**: traefik, postgres (recommended)
- **Effort**: `hard` — multi-component (forgejo, runners for CI, postgres), complex auth setup
- **Notes**: Runners need separate deployment.

### Weblate

Translation management platform. Web-based with API and CLI support.

<https://docs.weblate.org/en/latest/>

- **Layer**: 7 (dev) — development services
- **Priority**: `medium`
- **Dependencies**: traefik, postgres
- **Effort**: `medium` — multi-container (web, redis, postgres)
- **Notes**: Integrates with Forgejo for i18n workflows.

### LibreTranslate

Self-hosted translation API. Neural machine translation with multiple language pairs.

<https://docs.libretranslate.com/>

- **Layer**: 7 (dev) — development services
- **Priority**: `medium`
- **Dependencies**: traefik
- **Effort**: `medium` — single container, needs NVIDIA GPU for CUDA acceleration
- **Notes**: CUDA support requires GPU passthrough in compose. Without GPU, CPU inference is slow.

### Apprise API Server

Unified notification API. Sends alerts to 80+ platforms (Telegram, Discord, email, push, and more).

<https://appriseit.com/api/deployment/>

- **Layer**: 7 (dev) — development services
- **Priority**: `medium`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, no DB
- **Notes**: Centralizes alerting from Uptime Kuma, n8n, backup jobs, and any service that needs notifications.

### docat

Simple hosting for static documentation. Upload ZIP archives, serves versioned docs.

<https://github.com/docat-org/docat>

- **Layer**: 7 (dev) / 3 (shared) — could serve as shared infrastructure for project docs
- **Priority**: `low`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, no DB
- **Notes**: Useful for project documentation, API references, and internal wikis.

### Hoppscotch

Open-source API platform. Test REST and GraphQL APIs, manage collections, collaborate.

<https://docs.hoppscotch.io/documentation/self-host/getting-started>

- **Layer**: 7 (dev) — development services
- **Priority**: `medium`
- **Dependencies**: traefik, postgres
- **Effort**: `medium` — multi-container (platform, worker, postgres)
- **Notes**: Self-hosted alternative to Postman. Useful for API development and testing.

### Authentik

Identity provider. SSO, OAuth, SAML, LDAP for all services.

<https://docs.goauthentik.io/>

- **Layer**: 3 (shared) or 6 (home) — foundational infra vs. user-facing
- **Priority**: `medium`
- **Dependencies**: traefik, postgres
- **Effort**: `hard` — multi-container (server, worker, postgres, redis), complex integration with existing services
- **Notes**: Would replace per-service auth. Major integration work to connect existing services (Traefik, Homepage, etc.).

### Wiki

Knowledge base and documentation wiki.

Two candidates:

**Leafwiki** — <https://github.com/perber/leafwiki>

- **Layer**: 6 (home) or 7 (dev)
- **Priority**: `low`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, file-based storage
- **Notes**: Minimalist, markdown-based, Git-backed. Lightweight but limited features.

**Wiki.js** — <https://docs.requarks.io/>

- **Layer**: 6 (home) or 7 (dev)
- **Priority**: `medium`
- **Dependencies**: traefik, postgres
- **Effort**: `medium` — single container, postgres required
- **Notes**: Feature-rich: permissions, search, Git sync, multiple editors. Heavier but more capable.

### Pulp

Content management system for software packages. Serves apt, pip, npm, container images, and more.

<https://pulpproject.org/user/>

- **Layer**: 3 (shared) — foundational infrastructure
- **Priority**: `medium`
- **Dependencies**: traefik, postgres, S3-compatible storage
- **Effort**: `hard` — multi-component (core, content app, plugin per package type), complex setup
- **Notes**: Private package registry for apt, pip, npm, container images, and more.

### Lynis

Security-focused system auditor. Scans hardening state, generates reports and recommendations.

<https://cisofy.com/lynis/>

- **Layer**: 2 (os_services) — native binary
- **Priority**: `medium`
- **Dependencies**: none
- **Effort**: `easy` — native binary, no daemon, runs on demand
- **Notes**: Can be scheduled via cron or Ansible. Hardening log stored for trend tracking.

### Cockpit

Web-based server management UI. System overview, services, containers, logs, terminal.

<https://cockpit-project.org/documentation.html>

- **Layer**: 2 (os_services) — native package, systemd-managed
- **Priority**: `medium`
- **Dependencies**: traefik (for web access on :9090)
- **Effort**: `easy` — `apt install cockpit`, systemd service
- **Notes**: Complements DockHand (which manages Docker) by providing OS-level management. Cockpit's Docker plugin overlaps with DockHand; prefer Cockpit for OS tasks, DockHand for container orchestration.

### Koillection

Collection tracking and cataloging. Manage books, games, movies, vinyl, and custom collections.

<https://github.com/benjaminjonard/koillection>

- **Layer**: 6 (home) — user-facing
- **Priority**: `low`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, SQLite storage
- **Notes**: Complements CWA (e-books) by tracking physical collections. Barcode scanning support.

### Memos

Self-hosted memo and note-taking. Lightweight alternative to Google Keep.

<https://github.com/usememos/memos>

- **Layer**: 6 (home) — user-facing
- **Priority**: `low`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, SQLite storage
- **Notes**: Markdown support, tags, boards. Good for quick notes and task tracking.

### HomeBox / Grocy

Pantry and household management. Track food items, recipes, chores, and inventory.

Two candidates:

**HomeBox** — <https://homebox.software/en/>

- **Layer**: 6 (home) — user-facing
- **Priority**: `low`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, SQLite storage
- **Notes**: Modern UI, actively developed.

**Grocy** — <https://grocy.info/>

- **Layer**: 6 (home) — user-facing
- **Priority**: `low`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, SQLite storage
- **Notes**: More feature-complete (meals, appliances, tools, pets). UI feels dated.

### S3-compatible storage

Distributed object storage. Needed for Loki retention, potential future services (Paperless, Nextcloud external storage, etc.).

Two candidates under evaluation:

**RustFS** — <https://docs.rustfs.com/>

- **Layer**: 3 (shared) — foundational infrastructure
- **Priority**: `medium`
- **Dependencies**: traefik (for console UI)
- **Effort**: `easy` — single container, drop-in MinIO replacement
- **Notes**: MinIO fork rewritten in Rust. API-compatible, aims for better performance. Single-node friendly.

**GarageHQ** — <https://garagehq.deuxfleurs.fr/documentation/>

- **Layer**: 3 (shared) — foundational infrastructure
- **Priority**: `medium`
- **Dependencies**: traefik (for web UI)
- **Effort**: `medium` — cluster-aware, needs 3+ nodes for erasure coding (or single-node degraded mode)
- **Notes**: Designed for multi-node clusters with erasure coding. Rust-based. Better fit if we plan horizontal scaling; overkill for single-node.

---

### Deck Lotus

Self-hosted Magic: The Gathering deck builder with Mana Pool integration, price monitoring, cart optimization, and multi-user support.

<https://github.com/madeofpendletonwool/deck-lotus>

- **Layer**: 6 (home) — user-facing
- **Priority**: `low`
- **Dependencies**: traefik
- **Effort**: `easy` — single container, SQLite storage
- **Notes**: Deck building, price watches with ntfy push notifications, Mana Pool cart optimizer, deck sharing, multi-user with JWT auth.

---

_Add new entries above. When an entry moves to implementation, create a numbered plan (e.g., `021-add-<service>.md`) and link back here._
