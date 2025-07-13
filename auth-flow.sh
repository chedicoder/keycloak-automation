#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"

#  Get Admin Token 
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -k -X POST "$KEYCLOAK_URL/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d 'grant_type=password' \
  -d "client_id=$CLIENT_ID" | jq -r '.access_token')
echo "Token retrieved."

# Create Custom Authentication Flow 
echo "Creating custom authentication flow 'chedi Custom Lastlogintime'..."
curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/authentication/flows" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "chedi Custom Lastlogintime",
    "description": "Custom flow for chedi",
    "providerId": "basic-flow",
    "topLevel": true,
    "builtIn": false
}'

# Add Executions to Main Flow 
declare -a MAIN_EXECUTIONS=(
  "auth-cookie"
  "auth-spnego"
  "identity-provider-redirector"
)

for exec in "${MAIN_EXECUTIONS[@]}"; do
  echo "Adding main execution: $exec"
  curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/authentication/flows/chedi%20Custom%20Lastlogintime/executions/execution" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"provider\": \"$exec\"}"
done

# Create Subflow 
echo "Creating subflow 'chedi Custom Lastlogintime Forms'..."
curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/authentication/flows/chedi%20Custom%20Lastlogintime/executions/flow" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "chedi Custom Lastlogintime Forms",
    "type": "basic-flow",
    "provider": "basic-flow",
    "description": "Subflow for chedi",
    "builtIn": false
}'

sleep 2

# Add Sub-executions 
declare -a SUB_EXECUTIONS=(
  "auth-username-password-form"
  "select-app-user-authenticator"
  "conditional-user-configured"
  "auth-otp-form"
  "last_login_time_authenticator"
)

for sub_exec in "${SUB_EXECUTIONS[@]}"; do
  echo "Adding sub-execution: $sub_exec"
  curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/authentication/flows/chedi%20Custom%20Lastlogintime%20Forms/executions/execution" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"provider\": \"$sub_exec\"}"
done

echo "Retrieving execution ID for 'select-app-user-authenticator'..."
EXECUTIONS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/$REALM/authentication/flows/chedi%20Custom%20Lastlogintime%20Forms/executions")

SELECT_EXEC_ID=$(echo "$EXECUTIONS_JSON" | jq -r '.[] | select(.providerId=="select-app-user-authenticator") | .id')

if [ -z "$SELECT_EXEC_ID" ]; then
  echo "❌ Could not find execution ID for 'select-app-user-authenticator'."
  exit 1
fi

# Add Config for Custom MSIC Authenticator 
echo "Adding config for 'select-app-user-authenticator'..."
curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/authentication/executions/$SELECT_EXEC_ID/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "Custom MSIC Authenticator",
    "config": {
      "appLdapName": "PingDS"
    }
}'

# Set custom Browser Flow as the default browser flow
echo "Setting 'chedi Custom Lastlogintime' as the default browser flow..."
curl -s -k -X PUT "$KEYCLOAK_URL/auth/admin/realms/$REALM" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"browserFlow\": \"chedi Custom Lastlogintime\"}"


echo "✅ Authentication flow setup complete."
