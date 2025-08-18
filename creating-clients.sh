#!/bin/bash
set +H  

KEYCLOAK_URL="http://localhost.8080"
REALM="test"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"
CLIENTS_FILE="clients.json"

# Getting admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -k -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d 'grant_type=password' \
  -d "client_id=$CLIENT_ID" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "Failed to get admin token."
  exit 1
fi

if [[ ! -f "$CLIENTS_FILE" ]]; then
  echo "❌ Clients file $CLIENTS_FILE not found."
  exit 1
fi

echo "Creating clients ..."

jq -c '.[]' "$CLIENTS_FILE" | while read -r client; do
  CLIENT_ID_VALUE=$(echo "$client" | jq -r '.clientId')

  EXISTS=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_ID_VALUE" | jq length)

  if [[ "$EXISTS" -gt 0 ]]; then
    echo "⚠️ Client '$CLIENT_ID_VALUE' already exists, skipping."
    continue
  fi

  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$client")

  if [[ "$RESPONSE_CODE" == "201" ]]; then
    echo "➕ Client '$CLIENT_ID_VALUE' created successfully."
  fi  
done    



