#!/bin/bash
set +H

KEYCLOAK_URL="https://app.msicint.iamdg.net.ma/auth"
REALM="master"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
FLOW_ALIAS="Msic%20Custom%20Lastlogintime"

# 🔐 Get token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -k -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
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
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "Msic Custom Lastlogintime",
    "description": "",
    "providerId": "basic-flow",
    "builtIn": false,
    "topLevel": true
}'

# Add Cookie execution: 

COOKIE_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Cookie") | .id')

echo "✅ Cookie provider ID: $COOKIE_PROVIDER_ID"
echo "Adding execution..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$COOKIE_PROVIDER_ID\"}"

# change execution requirement

COOKIE_EXECUTION_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$COOKIE_PROVIDER_ID\") | .id")

if [[ -z "$COOKIE_EXECUTION_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "✅ Execution ID: $COOKIE_EXECUTION_ID"

echo "Updating execution requirement to ALTERNATIVE..."
RESPONSE=$(curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$COOKIE_EXECUTION_ID\",
    \"requirement\": \"ALTERNATIVE\"
  }"
)
echo "Cookie added successfully" 

# Add Kerberos:
Kerberos_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Kerberos") | .id')

echo "✅ Kerberos provider ID: $Kerberos_PROVIDER_ID"

echo "Adding execution..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Kerberos_PROVIDER_ID\"}"

echo "kerberos added successfully" 

# Add Identity Provider Redirector:
Identity_Provider_Redirector_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Identity Provider Redirector") | .id')

echo "✅ Identity Provider Redirector provider ID: $Identity_Provider_Redirector_PROVIDER_ID"

echo "Adding execution..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Identity_Provider_Redirector_PROVIDER_ID\"}"

echo "Identity Provider Redirector added successfully"

# change execution requirement

Identity_Provider_Redirector_EXECUTION_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$Identity_Provider_Redirector_PROVIDER_ID\") | .id")

if [[ -z "$Identity_Provider_Redirector_EXECUTION_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "Updating execution requirement to ALTERNATIVE..."
RESPONSE=$(curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$Identity_Provider_Redirector_EXECUTION_ID\",
    \"requirement\": \"ALTERNATIVE\"
  }"
)

# low priority 
curl -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/executions/$Identity_Provider_Redirector_EXECUTION_ID/lower-priority" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"


# Add sub flow
curl -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/flow" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "Msic Custom Lastlogintime lastlogintime forms",
    "description": "Username, password, otp and other auth forms.",
    "provider": "registration-page-form",
    "type": "basic-flow"
}'

SUB_FLOW_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Msic Custom Lastlogintime lastlogintime forms") | .id')

if [[ -z "$SUB_FLOW_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "Updating SUB_FLOW requirement to ALTERNATIVE..."
curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$SUB_FLOW_ID\",
    \"requirement\": \"ALTERNATIVE\"
  }"


# Add Username Password Form in sub flow
Username_Password_Form_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Username Password Form") | .id')

curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20forms/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Username_Password_Form_PROVIDER_ID\"}"


# Add Select Applicative User in sub flow
Select_Applicative_User_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Select Applicative User") | .id')

curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20forms/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Select_Applicative_User_PROVIDER_ID\"}"


Select_Applicative_User_EXECUTION_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20forms/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$Select_Applicative_User_PROVIDER_ID\") | .id")

curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/executions/$Select_Applicative_User_EXECUTION_ID/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "Custom MSIC Authenticator", 
    "config": {
        "applicativeLdapStoreName": "PingDS"
    }
  }'

# Add sub flow in sub flow
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20forms/executions/flow" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "Msic Custom Lastlogintime lastlogintime Browser - Conditional OTP",
    "description": "Flow to determine if the OTP is required for the authentication",
    "provider": "registration-page-form",
    "type": "basic-flow"
}'

SUB_SUB_FLOW_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20forms/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Msic Custom Lastlogintime lastlogintime Browser - Conditional OTP") | .id')

if [[ -z "$SUB_SUB_FLOW_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "Updating SUB_SUB_FLOW requirement to CONDITIONAL..."
curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20forms/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$SUB_SUB_FLOW_ID\",
    \"requirement\": \"CONDITIONAL\"
  }"

# Add condition in sub flow sub flow
Condition_user_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Condition - user configured") | .id')

echo "✅ Condition user provider ID: $Condition_user_PROVIDER_ID"
echo "Adding condition..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20Browser%20-%20Conditional%20OTP/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Condition_user_PROVIDER_ID\"}"

# change execution requirement

Condition_user_EXECUTION_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20Browser%20-%20Conditional%20OTP/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$Condition_user_PROVIDER_ID\") | .id")

if [[ -z "$Condition_user_EXECUTION_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "Updating execution requirement to Required..."
RESPONSE=$(curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20Browser%20-%20Conditional%20OTP/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$Condition_user_EXECUTION_ID\",
    \"requirement\": \"REQUIRED\"
  }"
)

# Add execution in sub flow sub flow
OTP_form_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "OTP Form") | .id')

echo "✅ OTP Form provider ID: $OTP_form_PROVIDER_ID"
echo "Adding execution..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20Browser%20-%20Conditional%20OTP/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$OTP_form_PROVIDER_ID\"}"


# change execution requirement

OTP_form_EXECUTION_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20Browser%20-%20Conditional%20OTP/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$OTP_form_PROVIDER_ID\") | .id")

if [[ -z "$OTP_form_EXECUTION_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "Updating execution requirement to Required..."
RESPONSE=$(curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/Msic%20Custom%20Lastlogintime%20lastlogintime%20Browser%20-%20Conditional%20OTP/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$OTP_form_EXECUTION_ID\",
    \"requirement\": \"REQUIRED\"
  }"
)

# Add Record Login Time execution: 

Record_Login_Time_PROVIDER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/authenticator-providers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.[] | select(.displayName == "Record Login Time") | .id')

echo "Adding execution..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/execution" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\": \"$Record_Login_Time_PROVIDER_ID\"}"

# change execution requirement

Record_Login_Time_EXECUTION_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$Record_Login_Time_PROVIDER_ID\") | .id")

if [[ -z "$Record_Login_Time_EXECUTION_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "Updating execution requirement to ALTERNATIVE..."
curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$Record_Login_Time_EXECUTION_ID\",
    \"requirement\": \"REQUIRED\"
  }"