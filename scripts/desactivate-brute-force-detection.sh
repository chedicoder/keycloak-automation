#!/bin/bash
set +H

KEYCLOAK_URL="https://app.msicuat.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"

# Getting admin token
echo "Getting admin token..."
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

curl -s -k -X PUT "$KEYCLOAK_URL/admin/realms/$REALM" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"bruteForceProtected": false}'


echo "✔️ Brute force detection disabled successfully."