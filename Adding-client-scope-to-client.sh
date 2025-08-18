#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma/auth"
export ECM_EOC_PCS_ENV_URL="ecm-eoc-pcs.msicint.iamdg.net.ma"
export APP_ENV_URL="app.msicint.iamdg.net.ma"

# Get the Pingds bindcredential from secret dirmanager.pw in secrets of pingds ns
export PING_DS_BIND_CREDENTIAL="7xZrAR1ITrpLvOSWlM8CeS5JmqCjSL4c"
export LDAP_MT_BIND_CREDENTIAL="sso$modernSic*25"

REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
MAPPER_FILE1="PingDS-mappers.json"
MAPPER_FILE2="LDAP-MT-mappers.json"
PingDS_name="PingDS1"
LDAP_name="LDAP_MT1"
USERS_FILE="users.json"
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

# Adding client scope to client
echo "Adding client scope '$SCOPE_NAME' to client '$CLIENT_NAME'..."
# ID client
CLIENT_ID=$(curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_NAME" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  | jq -r '.[0].id')

# ID scope
SCOPE_ID=$(curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  | jq -r ".[] | select(.name==\"$SCOPE_NAME\") | .id")

if [[ "$SCOPE_TYPE" == "default" ]]; then
  ENDPOINT="default-client-scopes"
else
  ENDPOINT="optional-client-scopes"
fi

# Ajouter le scope au client
curl -s -X PUT \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_ID/$ENDPOINT/$SCOPE_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json"

echo "✅ Client scope '$SCOPE_NAME' ajouté en $SCOPE_TYPE au client '$CLIENT_NAME'"
