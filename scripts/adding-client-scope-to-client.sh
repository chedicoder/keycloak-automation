#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
SCOPE_NAME="test1"
CLIENT_NAME="test"
SCOPE_TYPE= "default" # or "optional"

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

# Adding client scope to client
echo "Adding client scope '$SCOPE_NAME' to client '$CLIENT_NAME'..."

# Getting client ID
CLIENT_ID=$(curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_NAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq -r '.[0].id')

# Getting  client scope id
SCOPE_ID=$(curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq -r ".[] | select(.name==\"$SCOPE_NAME\") | .id")

if [[ "$SCOPE_TYPE" == "default" ]]; then
  ENDPOINT="default-client-scopes"
else
  ENDPOINT="optional-client-scopes"
fi

# Add client scope to client
curl -s -X PUT \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_ID/$ENDPOINT/$SCOPE_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"

echo "✅ Client scope '$SCOPE_NAME' added as $SCOPE_TYPE to client '$CLIENT_NAME'"
