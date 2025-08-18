#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
CLIENT_SCOPES_FILE="../client-scopes.json"

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

if [[ ! -f "$CLIENT_SCOPES_FILE" ]]; then
  echo "❌ Client scopes file $CLIENT_SCOPES_FILE not found."
  exit 1
fi

# Creating client scopes
jq -c '.[]' "$CLIENT_SCOPES_FILE" | while read -r scope; do
  SCOPE_NAME=$(echo "$scope" | jq -r '.name')

  EXISTING_SCOPE_ID=$(curl -s -k -X GET \
    "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    | jq -r ".[] | select(.name==\"$SCOPE_NAME\") | .id")

  if [[ -n "$EXISTING_SCOPE_ID" ]]; then
    echo "⚠️  Client scope '$SCOPE_NAME' already exists (ID: $EXISTING_SCOPE_ID)"
  else
    curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$scope" > /dev/null
    echo "✅ Client scope created: $SCOPE_NAME"
  fi
done
