#!/bin/bash
set +H

KEYCLOAK_URL="http://localhost:8080"
REALM="test"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"
MAPPERS_FILE="../client-dedicated-mappers.json"

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
  NAME=$(echo "$mapper" | jq -r '.name')
  PROTOCOL=$(echo "$mapper" | jq -r '.protocol')
  PROTOCOL_MAPPER=$(echo "$mapper" | jq -r '.protocolMapper')
  CONFIG=$(echo "$mapper" | jq -c '.config')
  CLIENTS=$(echo "$mapper" | jq -c '.clients[]')

  echo "⚙️ Processing mapper: $NAME"

  for CLIENT in $CLIENTS; do
    CLIENT=$(echo "$CLIENT" | tr -d '"')

    # 4️⃣ Get client ID
    CLIENT_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
      "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT" | jq -r '.[0].id')

    if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "null" ]]; then
      echo "⚠️ Client $CLIENT not found."
      continue
    fi

    # 5️⃣ Check if mapper exists
    EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
      "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_ID/protocol-mappers/models" \
      | jq -r --arg NAME "$NAME" '.[] | select(.name==$NAME) | .id')

    if [[ -n "$EXISTS" ]]; then
      echo "✅ Mapper '$NAME' already exists in client '$CLIENT'. Skipping."
      continue
    fi

    # 6️⃣ Create mapper
    curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_ID/protocol-mappers/models" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"$NAME\",
        \"protocol\": \"$PROTOCOL\",
        \"protocolMapper\": \"$PROTOCOL_MAPPER\",
        \"config\": $CONFIG
      }"

    echo "✔️ Mapper '$NAME' added to client '$CLIENT'"
  done
done