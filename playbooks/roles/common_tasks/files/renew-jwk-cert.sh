#!/bin/bash
# JWK certificate auto-renewal script
# Deployed by common_tasks/register_jwk_renewal
# Args: $1=domain $2=cert_path $3=key_path $4=service_name

set -euo pipefail

DOMAIN="${1:?domain required}"
CERT="${2:?cert_path required}"
KEY="${3:?key_path required}"
SERVICE="${4:?service_name required}"
CA_URL="${5:?ca_url required}"
ISSUER="${6:?issuer required}"
JWK_KEY="/root/.step/secrets/jwk_priv.json"
RENEW_DAYS=30

# Check if cert exists
if [ ! -f "$CERT" ]; then
    logger -t jwk-renew "No cert at $CERT, skipping"
    exit 0
fi

# Check expiry
EXPIRY_EPOCH=$(date -d "$(openssl x509 -enddate -noout -in "$CERT" 2>/dev/null | cut -d= -f2)" +%s 2>/dev/null)
if [ -z "$EXPIRY_EPOCH" ]; then
    logger -t jwk-renew "Cannot read expiry from $CERT, skipping"
    exit 0
fi

NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

if [ "$DAYS_LEFT" -gt "$RENEW_DAYS" ]; then
    exit 0
fi

logger -t jwk-renew "Renewing $DOMAIN (${DAYS_LEFT} days left)"

# Resolve IP for SAN
HOST_IP=$(hostname -I | awk '{print $1}')

# Generate token (offline, local signing)
TOKEN=$(step-cli ca token "$DOMAIN" \
    --offline \
    --issuer "$ISSUER" \
    --key "$JWK_KEY" \
    --ca-url "$CA_URL" \
    --san "$DOMAIN" \
    --san "$HOST_IP" \
    --san "127.0.0.1")

# Issue certificate (contacts CA)
step-cli ca certificate --token "$TOKEN" --not-after 8760h \
    "$DOMAIN" "$CERT" "$KEY"

# Restart service
systemctl restart "$SERVICE"
logger -t jwk-renew "Renewed $DOMAIN, restarted $SERVICE"
