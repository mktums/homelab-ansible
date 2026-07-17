# 021: Refactor openwrt_step_ca into v2

**Priority**: High
**Difficulty**: Medium (8-10 files, router-only, no service disruption)
**Status**: ✅ Done (2026-07-17)

## Motivation

Audit of `openwrt_step_ca` revealed critical and significant issues:

### Critical
1. **JWK private key never persisted** — generated on router but never slurped to controller. `vault_step_ca_jwk_priv` exists in vault example but role never populates it. Router re-image = lost offline issuance capability for all server roles.
2. **JWK restore incomplete** — restore block only writes `jwk_pub.json`, never `jwk_priv.json`. A full router re-image can't recover offline issuance.

### Significant
3. **Destructive init** — deletes `certs/` and `secrets/` on fresh init. No recovery if `ca.json` exists but is corrupted.
4. **Dual password files** — `ca_password.txt` and `intermediate_ca_key_pass` contain same value, different paths.
5. **No smoke tests** — no verification that ACME directory or JWK provisioner works after deploy.
6. **Temp directory leak** — `/tmp/step-ca/` never cleaned up after binary install.
7. **Hardcoded URLs** — `ca-install.html` hardcodes `step-ca.lan:8443`.
8. **Flat task structure** — `init.yml` is 263 lines of mixed concerns (CA init, JWK, config, service, trust store).

## Affected files

### New files (v2 role, now renamed to openwrt_step_ca)
- `playbooks/roles/os_services/openwrt_step_ca/defaults/main.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/main.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/cname.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/binary_install.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/user_setup.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/ca_init.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/jwk_setup.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/config_deploy.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/service_setup.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/trust_store.yml`
- `playbooks/roles/os_services/openwrt_step_ca/tasks/smoke_test.yml`
- `playbooks/roles/os_services/openwrt_step_ca/handlers/main.yml`
- `playbooks/roles/os_services/openwrt_step_ca/templates/ca.json.j2`
- `playbooks/roles/os_services/openwrt_step_ca/templates/step-ca.init.j2`
- `playbooks/roles/os_services/openwrt_step_ca/templates/ca-install.html.j2`

### Modified files
- `playbooks/router.yml` — switch role reference to v2
- `vault/secrets.example.yml` — add `vault_step_ca_intermediate_password`, `vault_step_ca_jwk_password`

### Existing v1 role
- Left in place until v2 is verified. Can be removed after.

## Design decisions

### Key lifecycle
- **All keys slurped to controller**: root cert, root key, JWK pub, JWK priv. Saved to `vault/` directory. Base64 printed for user to copy to `vault/secrets.yml`.
- **Idempotent restore**: If vault has keys, always restore from vault. No "skip if ca.json exists" logic.
- **Force reinit**: `step_ca_force_reinit: true` flag to force fresh generation.
- **JWK verification**: After restoring JWK pub key, verify thumbprint matches ca.json provisioner key.

### Password model
| Vault key | Purpose | Used by |
|-----------|---------|---------|
| `vault_step_ca_password` | Root CA key password | `step ca init --password-file` |
| `vault_step_ca_intermediate_password` | Intermediate key password | `--password-file` runtime flag, ca.json `key_password_file` |
| `vault_step_ca_jwk_password` | JWK provisioner password | Online token generation, smoke test |

Single password file (`ca_password.txt`) for intermediate at runtime. Root password file only used during init.

### Task structure
Each task file handles one concern:
- `binary_install.yml` — install step-ca + step CLI with per-binary temp dirs and cleanup
- `user_setup.yml` — create step system user
- `ca_init.yml` — generate or restore CA from vault
- `jwk_setup.yml` — generate or restore JWK keys, verify thumbprint
- `config_deploy.yml` — render ca.json, set ownership
- `service_setup.yml` — deploy init script, start/restart service
- `trust_store.yml` — install root CA in OpenWrt local trust store
- `smoke_test.yml` — health check, ACME directory, JWK token test

### Procd init script
- `procd_set_param signal SIGHUP` for standard reload
- No custom `reload_service` function
- Ansible uses `community.openwrt.service` with `state: reloaded` for config changes

### Smoke tests
- `curl -sk https://127.0.0.1:8443/health` — service running
- `curl -sk https://127.0.0.1:8443/.well-known/acme/directory` — ACME provisioner active
- `step ca token --provisioner admin@... --password` — JWK provisioner works (online)

### Templates
- `ca-install.html.j2` — uses `{{ step_ca_cname }}.{{ lan_domain }}:{{ step_ca_port }}`
- `ca.json.j2` — JWK provisioner includes `password` field
- `step-ca.init.j2` — cleaned up procd script with `signal SIGHUP`

## Implementation steps

1. Create v2 role directory structure
2. Write `defaults/main.yml` with new vars
3. Write task files (binary_install, user_setup, ca_init, jwk_setup, config_deploy, service_setup, trust_store, smoke_test, cname)
4. Write templates (ca.json.j2, step-ca.init.j2, ca-install.html.j2)
5. Write handlers/main.yml
6. Update `router.yml` to use v2 role
7. Update `vault/secrets.example.yml` with new password vars
8. Test on actual router

## Migration

No automatic migration. V2 reuses existing data at `/etc/step-ca/` if present. If missing, generates or restores from vault. User runs v2 playbook — if vault has keys, v2 restores. If not, v2 generates fresh and prompts user.

After v2 is verified working, remove v1 role directory.

## Dependencies

- `community.openwrt.init` must run before this role (already in router.yml)
- `barebone/openwrt_base` must run before this role (already in router.yml)
- No dependencies on server roles (step_cli, docker, etc. depend on this role, not vice versa)
