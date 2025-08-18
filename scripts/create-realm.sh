#!/bin/bash
KEYCLOAK_URL="http://localhost:8080"
REALM="test"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"

# Obtenir le token admin
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d 'grant_type=password' \
  -d "client_id=$CLIENT_ID" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "❌ Failed to get admin token."
  exit 1
fi

# Créer le realm
curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
        \"realm\": \"$REALM\",
        \"enabled\": true
      }"

echo "✔️ Realm '$REALM' created."
