#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
MAPPER_FILE="../PingDS-mappers.json"
PingDS_name="LDAP_MT"

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

if [[ ! -f "$MAPPER_FILE" ]]; then
  echo "❌ Fichier $MAPPER_FILE introuvable."
  exit 1
fi

# PINGDS_ID=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
#   "$KEYCLOAK_URL/admin/realms/$REALM/components?parent=$REALM&type=org.keycloak.storage.UserStorageProvider" \
#   | jq -r --arg name "$PingDS_name" '.[] | select(.name == $name) | .id')

PINGDS_ID="tLJzxN5AQRKS05385MrXqA"

EXISTING_MAPPERS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components?parent=$PINGDS_ID&type=org.keycloak.storage.ldap.mappers.LDAPStorageMapper")

jq -c '.[]' "$MAPPER_FILE" | while read -r mapper; do
  NAME=$(echo "$mapper" | jq -er '.name' 2>/dev/null || echo "UNKNOWN")

  if echo "$EXISTING_MAPPERS_JSON" | jq -e ".[] | select(.name==\"$NAME\")" > /dev/null; then
    echo "✅ Mapper '$NAME' exists."
  else
    RESPONSE=$(curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/components" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(echo "$mapper" | jq --arg parentId "$PINGDS_ID" '. + {parentId: $parentId, providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"}')")

    if echo "$RESPONSE" | grep -q 'error'; then
      echo "❌ Échec de l'ajout du mapper '$NAME'. Réponse : $RESPONSE"
    else
      echo "➕ Mapper '$NAME' added."
    fi
  fi
done

