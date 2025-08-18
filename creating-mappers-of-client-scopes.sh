#!/bin/bash
set +H

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
MAPPERS_FILE="client_scopes_mappers.json"

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

if [[ ! -f "$MAPPERS_FILE" ]]; then
  echo "❌ Mappers file $MAPPERS_FILE not found."
  exit 1
fi

jq -c '.[]' "$MAPPERS_FILE" | while read -r mapper; do
  MAPPER_NAME=$(echo "$mapper" | jq -r '.name')
  PROTOCOL=$(echo "$mapper" | jq -r '.protocol')
  PROTOCOL_MAPPER=$(echo "$mapper" | jq -r '.protocolMapper')
  CONFIG=$(echo "$mapper" | jq -c '.config')
  CLIENT_SCOPES=$(echo "$mapper" | jq -r '.client_scopes[]')

  for CS_NAME in $CLIENT_SCOPES; do
    # Get client scope ID
    CS_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
      -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r --arg name "$CS_NAME" '.[] | select(.name==$name) | .id')

    if [[ -z "$CS_ID" ]]; then
      echo "⚠️ Client scope '$CS_NAME' not found. Skipping mapper '$MAPPER_NAME'."
      continue
    fi

    # Check if mapper already exists
    EXISTING_MAPPER=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes/$CS_ID/protocol-mappers/models" \
      -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r --arg name "$MAPPER_NAME" '.[] | select(.name==$name) | .id')

    if [[ -n "$EXISTING_MAPPER" ]]; then
      echo "⚠️ Mapper '$MAPPER_NAME' already exists on client scope '$CS_NAME' (ID: $EXISTING_MAPPER)"
      continue
    fi

    # Create mapper
    curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes/$CS_ID/protocol-mappers/models" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
            \"name\": \"$MAPPER_NAME\",
            \"protocol\": \"$PROTOCOL\",
            \"protocolMapper\": \"$PROTOCOL_MAPPER\",
            \"config\": $CONFIG
          }" > /dev/null

    echo "✅ Mapper '$MAPPER_NAME' created for client scope '$CS_NAME'."
  done
done

echo "All mappers processed."
