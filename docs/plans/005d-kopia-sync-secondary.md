# 005d: Kopia sync-to secondary repository (local mirror)

## Motivation

Implement local disk mirroring for the primary Kopia repository using `kopia repository sync-to` — a blob-level copy from primary to secondary storage. This is the first layer of the planned 3-2-1 backup strategy. See [005a](./005a-kopia-server.md) for server deployment and original off-site replication plan.

**Status:** Implemented.

### Scope

| Component | Status |
|-----------|--------|
| sync-to secondary (WD Green SSD) | Done |
| Maintenance on secondary after each sync | Done |
| Verification timers (daily 5%, monthly 100%) | Done |
| Scheduled timer (04:30 daily, randomized delay) | Done |
| Manual trigger support (`systemctl start`) | Done |
| Tertiary target (Samsung T7 Shield USB) | Done |

### Storage layout

| Target | Device | Path | Purpose |
|--------|--------|------|---------|
| Primary | 2x WD Red 3TB mirror array | `/mnt/reds/!backup/repository` | Main repo, active backups |
| Secondary | WD Green SSD (~800GB free) | `/mnt/green/kopia-repo-sync` | Local mirror via sync-to |
| Tertiary | Samsung T7 Shield USB (exFAT) | `/mnt/t7/kopia-repo-sync` | Portable off-site copy via udev-triggered sync-to |

## Architecture

**Status:** Implemented. Sync-to runs inside the kopia-server container (already connected to primary), writes blobs directly to secondary path mounted as a bind volume. Maintenance and verification run in separate ephemeral containers targeting only the secondary path.

### How it works

1. **Sync** — `kopia repository sync-to filesystem --path <secondary>` copies all blobs from primary → secondary. Runs inside the server container via `docker compose exec`. Uses `--delete` flag to remove orphaned blobs on destination that no longer exist in source.
2. **Maintenance** — After sync completes, a separate `docker run` connects to the secondary repo and runs `maintenance set --owner=root@kopia && maintenance run --full`. This compacts fragmented blobs and runs GC on the secondary independently of primary's maintenance cycle.
3. **Verification** — Two dedicated timers verify the secondary repo integrity: daily 5% sample + monthly full audit, running in ephemeral containers (same pattern as primary verification but targeting secondary path).

### Systemd units

| Unit | Schedule | Command |
|------|----------|---------|
| `kopia-sync-secondary.timer` | Daily at 04:30 (+2h random delay) | Runs sync-to + maintenance script |
| `kopia-sync-verify.timer` | Daily (+2h random delay) | Verify 5% of files |
| `kopia-sync-verify-full.timer` | Monthly (+2h random delay) | Verify 100% of files |

Manual trigger: `sudo systemctl start kopia-sync-secondary.service &`

### Tertiary sync (Samsung T7 Shield USB)

Tertiary uses the same pattern as secondary but is triggered by udev instead of a timer — runs when the USB drive is plugged in.

| Component | Status |
|-----------|--------|
| udev rule on device plug-in (`/etc/udev/rules.d/99-kopia-t7.rules`) | Done |
| Script: mount + sync-to + maintenance | Done |
| `kopia-sync-tertiary.service` (oneshot) | Done |
| exFAT workaround (purge macOS AppleDouble files) | Done |

**Trigger:** Unplug/replug T7 Shield → udev creates `/dev/t7_shield1` symlink → systemd starts the oneshot service.

Manual trigger: `sudo systemctl start kopia-sync-tertiary.service`

### Script-based execution

The sync-to + maintenance chain runs from `/opt/ansible/kopia_server/kopia-sync-secondary/kopia-sync-secondary.sh`:

```bash
#!/bin/bash
set -e
# Step 1: Sync blobs (exec into running server container)
docker compose exec -T kopia-server kopia repository sync-to filesystem --path <secondary> --delete --no-progress

# Step 2: Maintenance on secondary (ephemeral container with matching hostname for identity check)
docker run --rm --hostname=kopia \
  -e KOPIA_PASSWORD=<password> \
  -v "<secondary>:<secondary>:rw" \
  <image>:<tag> \
  bash -c "kopia repository connect filesystem --path=<secondary> && kopia maintenance set --owner=root@kopia && kopia maintenance run --full"
```

**Why hostname=kopia?** Kopia checks `user@hostname` against the maintenance owner. The ephemeral container must match `root@kopia` or maintenance refuses to run. Server container and ephemeral containers are namespace-isolated — no conflict.

**Note:** The tertiary script originally omitted `--entrypoint /bin/bash` on the maintenance `docker run`, causing `kopia: error: expected command but got "bash"`. Fixed to match secondary pattern.

### Key design decisions

| Decision | Rationale |
|----------|-----------|
| Same password as primary | Simpler ops, secondary is a mirror not independent archive |
| `--delete` on sync-to | Keeps secondary clean — removes blobs source no longer has after GC |
| No pre-initialization of destination | `sync-to` auto-creates destination with matching format blob on first run; manual `repository create` produces incompatible format |
| Script-based instead of inline bash in unit file | Systemd can't handle nested quoting in ExecStart; script is cleaner and easier to debug |
| Separate containers for maintenance vs sync | Sync needs active server connection (exec), maintenance needs clean state (docker run) |

### Why not independent dual-repo model?

The alternative — two separate repos with different passwords, policies, and agents running snapshots independently — gives full policy independence but doubles backup I/O and runtime. For a local mirror protecting against drive failure, identical retention on both is acceptable. Policy divergence only matters if you want the secondary to keep things longer than primary, which sync-to can't do (source GC'd = destination blob gone).

## Affected files

| File | Change |
|------|--------|
| `playbooks/roles/infra/kopia_server/tasks/sync-secondary.yml` | New — all secondary deployment tasks |
| `playbooks/roles/infra/kopia_server/templates/kopia-sync-secondary.sh.j2` | New — sync-to + maintenance script |
| `playbooks/roles/infra/kopia_server/templates/kopia-sync-secondary.timer.j2` | New — daily sync timer |
| `playbooks/roles/infra/kopia_server/templates/kopia-sync-secondary.service.j2` | New — oneshot service unit |
| `playbooks/roles/infra/kopia_server/templates/kopia-sync-verify.timer.j2` | New — daily verify timer |
| `playbooks/roles/infra/kopia_server/templates/kopia-sync-verify.service.j2` | New — daily verify service |
| `playbooks/roles/infra/kopia_server/templates/kopia-sync-verify-full.timer.j2` | New — monthly full verify timer |
| `playbooks/roles/infra/kopia_server/templates/kopia-sync-verify-full.service.j2` | New — monthly full verify service |
| `playbooks/roles/infra/kopia_server/defaults/main.yml` | Added `kopia_sync_secondary_enabled`, `kopia_sync_secondary_repo_path`, `kopia_sync_secondary_timer_on_calendar`, updated maintenance owner to `root@kopia` |
| `playbooks/roles/infra/kopia_server/templates/docker-compose.yml.j2` | Added conditional volume mount for secondary path, added hostname |

## Rollback

Disable `kopia_sync_secondary_enabled` in group_vars/host_vars and re-run playbook. Secondary data persists on disk for future re-enablement.

