#!/bin/bash
set +H

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
ADMIN_CLIENT="admin-cli"
JSON_FILE="../client_scopes_to_clients.json"

# Getting admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -k -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d 'grant_type=password' \
  -d "client_id=$ADMIN_CLIENT" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "Failed to get admin token."
  exit 1
fi

# Check JSON file
if [[ ! -f "$JSON_FILE" ]]; then
  echo "JSON file $JSON_FILE not found!"
  exit 1
fi

jq -c '.[]' "$JSON_FILE" | while read client_entry; do
  CLIENT_NAME=$(echo "$client_entry" | jq -r '.client')
  echo "Processing client: $CLIENT_NAME"

  # Get client ID
  CLIENT_ID=$(curl -s -k -X GET \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_NAME" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    | jq -r '.[0].id')

  if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "null" ]]; then
    echo "❌ Client $CLIENT_NAME not found, skipping..."
    continue
  fi

  # Loop over scopes for this client
  echo "$client_entry" | jq -c '.scopes[]' | while read scope_entry; do
    SCOPE_NAME=$(echo "$scope_entry" | jq -r '.name')
    SCOPE_TYPE=$(echo "$scope_entry" | jq -r '.type')

    # Get scope ID
    SCOPE_ID=$(curl -s -k -X GET \
      "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      | jq -r ".[] | select(.name==\"$SCOPE_NAME\") | .id")

    if [[ -z "$SCOPE_ID" || "$SCOPE_ID" == "null" ]]; then
      echo "❌ Client scope $SCOPE_NAME not found, skipping..."
      continue
    fi

    # Determine endpoint
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

    echo "✅ Added $SCOPE_NAME ($SCOPE_TYPE) to $CLIENT_NAME"
  done
done
