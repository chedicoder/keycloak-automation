#!/bin/bash
set +H  

# il faut ajouter au client EB-CLIENT (default) : openid et minio clientscopes
# il faut ajouter au client avm-admin-cli (default) : acr, address,email,microprofile-jwt,offline_access,openid,phone,profile,roles,web-origins

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
SCOPE_NAME="web-origins"
CLIENT_NAME="avm-admin-cli"
SCOPE_TYPE="default" # or "optional"

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
CLIENT_ID=$(curl -s -k -X GET \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_NAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq -r '.[0].id')
echo "Client ID: $CLIENT_ID"
# Getting  client scope id
SCOPE_ID=$(curl -s -k -X GET \
  "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq -r ".[] | select(.name==\"$SCOPE_NAME\") | .id")

echo "Client Scope ID: $SCOPE_ID"
if [[ "$SCOPE_TYPE" == "default" ]]; then
  ENDPOINT="default-client-scopes"
else
  ENDPOINT="optional-client-scopes"
fi

# Add client scope to client
curl -s -k -X PUT \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_ID/$ENDPOINT/$SCOPE_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"

echo "✅ Client scope '$SCOPE_NAME' added as $SCOPE_TYPE to client '$CLIENT_NAME'"
