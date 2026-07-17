# 020: R&D — universal compose template for common blocks

## Status

📋 Planned (R&D)

## Motivation

15 compose templates repeat the same `/etc/ssl/certs/ca-certificates.crt` volume mount. Traefik and homepage labels are similarly duplicated (~150 lines across 15 files). Any change to these common blocks requires editing every affected template (Shotgun Surgery).

## Problem statement

Common blocks that appear across most compose templates:

| Block | Occurrences | Lines |
|-------|-------------|-------|
| CA cert volume mount | 15 | ~15 |
| Traefik labels (5 labels) | 20 services | ~100 |
| Homepage labels (5 labels) | 16 services | ~80 |

## Approaches to research

### A. Jinja2 include snippets (low risk)

Create `.j2` fragments in `common_tasks/templates/` included via `{% include %}`.

- **Pros**: Simple, no new role, works with existing template rendering
- **Cons**: Include path resolution across roles (needs meta dependency or absolute path). Variable passing requires `{% with %}` or task-level `vars:`.
- **Research needed**: Does Ansible's template search path resolve cross-role includes when `common_tasks` is a meta dependency?

### B. Common task that renders universal compose (medium risk)

A shared task that takes service-specific params and renders the full compose file from a universal template.

- **Pros**: Single source of truth for compose structure
- **Cons**: Significant restructuring. Each service's deploy task becomes a parameterized call. Multi-service compose files (inpx_web, arr_stack) complicate this. Handler `project_src` and `files` parameters must still be per-role.
- **Research needed**: Can a single template handle both single-service and multi-service compose files? How do service-specific blocks (healthcheck, deploy, depends_on) fit?

### C. Compose file inheritance (Docker-native)

Use Docker Compose's `extends` or multi-file overlay (`docker-compose -f base.yml -f service.yml`).

- **Pros**: Native Docker feature, no Ansible complexity
- **Cons**: `extends` is deprecated in Compose v2. Multi-file overlay requires orchestrating multiple files per service. Labels don't merge well across files.
- **Research needed**: Current state of Compose inheritance in v2.6+.

### D. Ansible compose role generator (high risk)

A role that generates the compose file from structured data (services as a list of dicts in defaults).

- **Pros**: Most flexible, fully parameterized
- **Cons**: Major rewrite. Loses readability of inline YAML. Complex services (healthcheck, deploy, volumes) become hard to express.
- **Research needed**: — (likely reject)

## Research questions

1. Which approach handles multi-service compose files (arr_stack: 6 services, inpx_web: 2 services)?
2. Can the approach coexist with service-specific blocks (healthcheck, deploy, ports, depends_on)?
3. What's the maintenance cost vs. duplication cost for each approach?
4. Does the approach work with Ansible `--check` mode?

## Deliverable

A short comparison document (`docs/adr/00X-compose-template-approach.md`) recommending one approach with a proof-of-concept (refactor one service as prototype).

## Scope

R&D only — no implementation until approach is selected and proven.

## Affected files (if implemented)

All `playbooks/roles/*/templates/docker-compose.yml.j2` (15+ files) and potentially handler files.
