#!/bin/bash
set +H

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
OUTPUT_FILE="groups.txt"

echo "🔑 Getting admin token..."
ADMIN_TOKEN=$(curl -s -k -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d 'grant_type=password' \
  -d "client_id=$CLIENT_ID" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
    echo "❌ Failed to get admin token."
    exit 1
fi

# Choisir la longueur de password (6), ou ne mettre rien "" pour desactiver le check de la longueur
curl -s -k -X PUT "https://$KEYCLOAK_URL/admin/realms/dxp" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "passwordPolicy": "length(6)" 
  }'
