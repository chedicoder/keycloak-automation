#!/bin/bash
set +H  

KEYCLOAK_URL="http://localhost:8080"
REALM="master"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"
BROWSER_AUTHENTIFICATION_FLOW="browser"

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

# Bind the authentication flow to the realm
curl -s -k -X PUT "$KEYCLOAK_URL/admin/realms/$REALM" \
-H "Authorization: Bearer $ADMIN_TOKEN" \
-H "Content-Type: application/json" \
-d "{\"browserFlow\":\"$BROWSER_AUTHENTIFICATION_FLOW\"}"

echo "🎉 Realm '$REALM' is now using '$BROWSER_AUTHENTIFICATION_FLOW' for browser authentication."
