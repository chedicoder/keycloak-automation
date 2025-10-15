#!/bin/bash
set +H

KEYCLOAK_URL="http://localhost:8080"
REALM="master"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"
FLOW_ALIAS="test"

# 🔐 Get token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "❌ Failed to get admin token."
  exit 1
fi

echo "✅ Token acquired."

# ➕ Add the flow
echo "Creating authentication flow..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "'"$FLOW_ALIAS"'",
    "description": "test description",
    "providerId": "basic-flow",
    "builtIn": false,
    "topLevel": true
}'

# Add Cookie execution: 

# 🔍 Get providerId = auth-cookie (from displayName)
COOKIE_PROVIDER_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Cookie") | .id')

echo "✅ Cookie provider ID: $COOKIE_PROVIDER_ID"
# ➕ Add the execution
echo "Adding execution..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$COOKIE_PROVIDER_ID\"}"

# 🔍 Get execution ID just added (by filtering providerId)
COOKIE_EXECUTION_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$COOKIE_PROVIDER_ID\") | .id")

if [[ -z "$COOKIE_EXECUTION_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "✅ Execution ID: $COOKIE_EXECUTION_ID"

echo "Updating execution requirement to ALTERNATIVE..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$COOKIE_EXECUTION_ID\",
    \"requirement\": \"ALTERNATIVE\"
  }"
)
echo "Cookie added successfully" 

# Add Kerberos:
Kerberos_PROVIDER_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Kerberos") | .id')

echo "✅ Kerberos provider ID: $Kerberos_PROVIDER_ID"

# ➕ Add the execution
echo "Adding execution..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Kerberos_PROVIDER_ID\"}"

echo "kerberos added successfully" 

# Add sub flow
curl -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/flow" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "test-sub flow",
    "description": "sqsq",
    "provider": "registration-page-form",
    "type": "basic-flow"
}'

SUBFLOW_EXECUTION_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "test-sub flow") | .id')


curl -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$SUBFLOW_EXECUTION_ID\",
    \"requirement\": \"ALTERNATIVE\"
}"

curl -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/executions/$SUBFLOW_EXECUTION_ID/lower-priority" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"

echo "sub flow added" 

# Add Username Password Form
Username_Password_Form_PROVIDER_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Username Password Form") | .id')

curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/test-sub%20flow/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Username_Password_Form_PROVIDER_ID\"}"


echo "sub Username Password Form added" 
