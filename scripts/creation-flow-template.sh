# ➕ create the flow
FLOW_ALIAS="test"

echo "Creating authentication flow..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "'"$FLOW_ALIAS"'",
    "description": "test description",
    "providerId": "basic-flow",
    "builtIn": false,
    "topLevel": true
}'

# Dans l'ajout de chaque execution et flow ou sub-flow on change dans le url la valeur de FLOW_ALIAS
# par le nom de flow parent (flow principale globale ou sub flow) 
# Si le nom de flow contient des espaces on change dans le url chaque espace par %20
# test flow => test%20flow 

# Add execution (on doit juste trouver le display name de cet execution pour l'ajouter): 

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
# The possible values are DISABLED, ALTERNATIVE and REQUIRED

COOKIE_EXECUTION_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.providerId == \"$COOKIE_PROVIDER_ID\") | .id")

if [[ -z "$COOKIE_EXECUTION_ID" ]]; then
  echo "❌ Could not retrieve execution ID."
  exit 1
fi

echo "Updating execution requirement to ALTERNATIVE..."
RESPONSE=$(curl -s -k -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$COOKIE_EXECUTION_ID\",
    \"requirement\": \"ALTERNATIVE\"
  }"
)

# low priority 
curl -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/executions/$COOKIE_EXECUTION_ID/lower-priority" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"

# Raise priority:
curl -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/executions/$COOKIE_EXECUTION_ID/raise-priority" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"

# add flow:
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/authentication/flows/$FLOW_ALIAS/executions/flow" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "sub flow",
    "description": "ss",
    "provider": "registration-page-form",
    "type": "basic-flow"
}'

# Le changement de priorité et de requirement est le meme que execution