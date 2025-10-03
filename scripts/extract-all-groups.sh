#!/bin/bash
set +H

# Il faut définir la taille maximale de groupes à exporter
# ici j'ai fixé à 500

KEYCLOAK_URL="https://app.msicint.iamdg.net.ma/auth"
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

echo "📂 Fetching groups from realm '$REALM'..."
curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
     "$KEYCLOAK_URL/admin/realms/$REALM/groups?search=&first=0&max=500&global=false" | jq -r '.[].name' > "$OUTPUT_FILE"

if [[ $? -eq 0 ]]; then
    echo "✅ Groups exported to $OUTPUT_FILE"
else
    echo "❌ Failed to export groups."
fi