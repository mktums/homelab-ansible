# 018: Add SearXNG metasearch engine

## Motivation

Add a privacy-respecting metasearch engine to the homelab for local web searching without telemetry or tracking.

## Affected files

| File | Change |
|------|--------|
| `playbooks/roles/tools/searxng/` | New role (layer 5) |
| `playbooks/site.yml` | Add role with `searxng` tag |
| `inventory/hosts.yml` | Add `searxng_hosts` group → `lab2` |
| `vault/secrets.yml` | Add `vault_searxng_secret` |

## Implementation steps

### Step 1: Generate secret key

Run on any Linux host (or WSL):

```bash
# Generate a random secret and print the vault line
openssl rand -base64 48 | xargs -I{} echo 'vault_searxng_secret: "{}"'
```

Paste the output into `vault/secrets.yml`.

### Step 2: Deploy

```bash
ansible-playbook playbooks/site.yml --tags searxng
```

### Step 3: Verify

- Access `https://search.<lan_domain>` and confirm the UI loads
- Run a test search and verify results appear
- Check Traefik logs for any TLS errors

## Configuration

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/searxng/searxng:latest` |
| Host | `lab2` |
| CNAME | `search` |
| Homepage group | `Apps` |
| Autocomplete | `duckduckgo` |
| Safe search | `0` (off) |
| Public instance | `false` |
| Theme | `simple` / `auto` |
| Formats | `html`, `json` |
| Request timeout | `5.0s` |
| Cache volume | Named Docker volume (`searxng-cache`) |
| Redis/Valkey | Not used (no limiter) |

## Rollback

SSH into lab2 and stop the container:

```bash
docker compose -f /opt/ansible/searxng/docker-compose.yml down
rm -rf /opt/ansible/searxng/
```

Then remove role from `site.yml` and `searxng_hosts` from `hosts.yml`.

## Status: Done

