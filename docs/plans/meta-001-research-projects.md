# meta-001: R&D — Interesting Projects

## Status

Living document

## Purpose

Collection of research topics, experiments, and proof-of-concept ideas. Not tied to a specific deployment — these are "what if" questions and technical explorations that could improve the infrastructure.

## Format

Each entry:

| Field | Description |
|-------|-------------|
| **Title** | Short name |
| **Status** | `idea` → `researching` → `prototype` → `adopted` / `rejected` |
| **Summary** | What it is, why it matters |
| **References** | Links, papers, repos, blog posts |
| **Risk/Effort** | Rough estimate |
| **Notes** | Findings, blockers, decisions |

## Entries

### 1. Universal compose template

Research how to eliminate duplicated volume mounts, traefik labels, and homepage labels across 15+ compose templates.

- **Status**: `researching` ([plan 020](020-universal-compose-template.md))
- **Summary**: 15 templates repeat the same CA cert mount, ~150 lines of repeated labels. Four approaches under evaluation: Jinja2 includes, common task, Docker inheritance, Ansible generator.
- **References**: —
- **Risk/Effort**: Medium
- **Notes**: See [020-universal-compose-template.md](020-universal-compose-template.md) for detailed approach comparison.

### 2. Offline recovery SOP

In the event of total internet cutoff, define procedures and tooling to (re)create and deploy all homelab services from backed-up data and cached software artifacts.

- **Status**: `idea`
- **Summary**: Current deployment assumes internet access for Docker image pulls, package installs, and Ansible galaxy collections. Need a recovery plan that covers: cached Docker images, offline package repositories, local Ansible collection cache, and a runbook for step-by-step recovery.
- **References**: —
- **Risk/Effort**: Hard
- **Notes**: Scope includes: (1) inventory of all external dependencies (images, packages, collections), (2) caching strategy (registry mirror, apt cache, Docker save/load), (3) recovery runbook with verification steps, (4) periodic drill to validate the SOP works.

---

_Add new entries above. Keep rejected entries — they're useful for "we tried this."_

