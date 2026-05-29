# Migrate Kopia server from Docker to native binary

## Motivation

Kopia server runs as a Docker container. The kopia binary supports running
as a native daemon with built-in snapshot scheduling. This eliminates systemd
timers on agent hosts.

## Current state

- `kopia_server`: Docker (docker-compose), lab1 only
- `kopia_agent`: native .deb, systemd timers for snapshots, lab1+lab2
- Server manages repository, sync-to, verification
- Agents trigger snapshots via systemd timers

## Target state

Both server and agent run the same `kopia server start` binary via systemd.

**lab1 (server)**

- Connect: `repository filesystem` (local repo at `/mnt/reds/!backup/repository`)
- Config: `/opt/ansible/kopia_server/`
- Verification: systemd timer (only server runs verification)
- Sync-to secondary/tertiary: systemd timer
- Snapshots: kopia policy scheduler (`--snapshot-time-crontab`)

**lab2 (agent)**

- Connect: `repository remote` (connects to lab1 via HTTPS)
- Config: `/opt/ansible/kopia_agent/`
- Snapshots: kopia policy scheduler (`--snapshot-time-crontab`)

## Design decisions

| Decision | Value | Rationale |
| --- | --- | --- |
| Repository location | Unchanged | Existing data stays in place |
| Installation method | .deb from GitHub | Same as agent, consistent |
| Run as | root | Backup paths owned by root |
| Snapshot scheduling | kopia policy crontab | Built-in scheduler replaces systemd timers |
| Verification | systemd timer | Kopia scheduler lacks verification support |
| Sync-to | systemd timer | Kopia scheduler lacks sync-to support |
| TLS | step-ca cert via Ansible | Kopia lacks ACME support |
| Agent to Server | control API over HTTPS | Existing control user provides API access |
| Roles | Two separate roles | Avoid guard complexity |
| Migration | Manual with SOP | One-time transition, not automated |

## Implementation steps

### 1. SOP for cleanup (manual, before Ansible)

- [ ] Stop Docker kopia server
- [ ] Preserve repository (`/mnt/reds/!backup/repository`)
- [ ] Preserve config dir (`/srv/docker_data/kopia_server/config/`)
- [ ] Remove Docker compose stack
- [ ] Remove Docker image

### 2. Update `kopia_server` role

- [ ] Replace Docker deploy with native binary (.deb install)
- [ ] Create systemd service unit (`kopia-server.service`)
- [ ] Environment file for secrets (not visible in `ps aux`)
- [ ] TLS cert management via step-ca (check expiration, 30-90 days)
- [ ] Keep sync-to secondary/tertiary as systemd timers
- [ ] Keep verification as systemd timer
- [ ] Remove Docker-related tasks

### 3. Update `kopia_agent` role

- [ ] Remove systemd snapshot timers
- [ ] Add schedule field to `backup_sources` in inventory (crontab format)
- [ ] Use `kopia policy set --snapshot-time-crontab` for schedules
- [ ] Agent connects to server via control API for user management
- [ ] Config paths move to `/opt/ansible/kopia_agent/`

### 4. Update inventory

- [ ] Add `schedule` field to each `backup_sources` entry (crontab format)
- [ ] Update `kopia_server_host` variable
- [ ] Move config paths to `/opt/ansible/`

### 5. Update `servers.yml`

- [ ] Adjust role order if needed
- [ ] Verify tags work correctly

## Affected files

- `playbooks/roles/infra/kopia_server/` (full rewrite, Docker to native)
- `playbooks/roles/infra/kopia_agent/tasks/register_source.yml` (remove timers, add policy schedules)
- `inventory/host_vars/lab1.yml` (add schedule to backup_sources)
- `inventory/host_vars/lab2.yml` (add backup_sources with schedule)
- `inventory/group_vars/servers.yml` (update kopia paths)
- `docs/plans/` (this file)

## Difficulty

Hard. Requires SOP, manual migration steps, role rewrite, inventory changes.
