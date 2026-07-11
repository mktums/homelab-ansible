# Add DockHand

**Status:** Done ✅

## Motivation

Add DockHand as a modern Docker management alternative to Portainer. Eventually replace Portainer.

## Decision log

| Decision | Resolution |
|----------|-----------|
| Hosts | lab1 (DockHand) + lab2 (Hawser Standard) |
| Subdomain | `dockhand.lan`, fallback `0.0.0.0:3000` |
| Data dir | `/srv/docker_data/dockhand` (matching paths, `DATA_DIR`) |
| Hawser mode | Standard, no TLS, `lab2.lan:2376` |
| Hawser stacks dir | `/srv/docker_data/dockhand_agent/stacks` (matching paths) |
| Socket access | GID matching (detect Docker group GID) |
| Encryption key | Auto-generated (Kopia backs up `.encryption_key`) |
| CA cert | `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` |
| Roles | `dockhand` + `dockhand_agent`, meta deps + guards |
| Init | API via `http://lab1.lan:3000`, `delegate_to: localhost` |
| Admin | `vault_admin_user` + `vault_dockhand_admin_password` |
| Lab1 env registration | Implemented but commented — DockHand auto-registers local socket |
| CNAME | Yes, via `common/register_cname` |
| Healthcheck | `GET /api/health` |
| Kopia backup | `dockhand` on lab1, `dockhand_agent` on lab2 |
| Image tags | Pinned: `fnsys/dockhand:v1.0.29`, `ghcr.io/finsys/hawser:v0.2.43` |

## Affected files

### New

- `playbooks/roles/services/dockhand/` — full role (tasks, handlers, defaults, templates, meta)
- `playbooks/roles/services/dockhand_agent/` — full role (tasks, handlers, defaults, templates, meta)

### Modified

- `playbooks/servers.yml` — add dockhand + dockhand_agent roles with guards
- `inventory/hosts.yml` — add `dockhand_hosts`, `dockhand_agent_hosts` groups
- `inventory/group_vars/servers.yml` — add `dockhand_admin_user`, `dockhand_admin_password`
- `vault/secrets.yml` — add `vault_dockhand_admin_password`
- `inventory/host_vars/lab1.yml` — add `dockhand` to `backup_sources`
- `inventory/host_vars/lab2.yml` — add `dockhand_agent` to `backup_sources`

## Implementation steps

### 1. Create `dockhand` role

- `defaults/main.yml` — image `v1.0.29`, paths, cname `dockhand`, port `3000`
- `templates/docker-compose.yml.j2` — traefik labels, group_add, DATA_DIR, NODE_EXTRA_CA_CERTS, volumes, healthcheck
- `tasks/deploy.yml` — create dirs, render compose, deploy via docker_compose_v2
- `tasks/init.yml` — wait for health, create user (idempotent), login, register lab1 env (commented)
- `tasks/cname.yml` — include `common/register_cname`
- `tasks/main.yml` — include deploy → init → cname
- `handlers/main.yml` — restart handler
- `meta/main.yml` — depends on `traefik`

### 2. Create `dockhand_agent` role

- `defaults/main.yml` — hawser image `v0.2.43`, paths, stacks dir
- `templates/docker-compose.yml.j2` — PORT=2376, STACKS_DIR matching, docker.sock, healthcheck
- `tasks/deploy.yml` — create dirs, render compose, deploy
- `tasks/init.yml` — login to DockHand on lab1, register lab2 env (direct, `lab2.lan:2376`)
- `tasks/main.yml` — include deploy → init
- `handlers/main.yml` — restart handler
- `meta/main.yml` — depends on `dockhand`

### 3. Update inventory

- `hosts.yml` — `dockhand_hosts: [lab1]`, `dockhand_agent_hosts: [lab2]`
- `servers.yml` — roles with `when: inventory_hostname in groups.get('dockhand_hosts', [])` guards
- `group_vars/servers.yml` — `dockhand_admin_user`, `dockhand_admin_password`
- `vault/secrets.yml` — `vault_dockhand_admin_password`

### 4. Update Kopia backups

- `host_vars/lab1.yml` — `dockhand` source → `/srv/docker_data/dockhand`
- `host_vars/lab2.yml` — `dockhand_agent` source → `/srv/docker_data/dockhand_agent`

## API endpoints used

| Endpoint | Purpose |
|----------|---------|
| `GET /api/health` | Wait for DockHand to be ready |
| `POST /api/users` | Create admin user (idempotent: check GET first) |
| `POST /api/auth/login` | Authenticate, get JWT |
| `POST /api/environments` | Register environment (lab1: socket, lab2: direct) |

## Dependency chain

```
traefik → dockhand → dockhand_agent
```

## Testing

```bash
# Deploy DockHand on lab1
ansible-playbook playbooks/servers.yml --tags dockhand

# Deploy Hawser on lab2
ansible-playbook playbooks/servers.yml --tags dockhand_agent

# Verify
ansible-playbook playbooks/servers.yml --tags dockhand,dockhand_agent
```

