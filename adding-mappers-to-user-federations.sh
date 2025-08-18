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

# Adding mappers to PingDS
if [[ ! -f "$MAPPER_FILE1" ]]; then
  echo "❌ Fichier $MAPPER_FILE1 introuvable."
  exit 1
fi

echo "🔍 Vérification et ajout des mappers depuis $MAPPER_FILE1 pour PingDS..."

EXISTING_MAPPERS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components/$PINGDS_ID/sub-components?type=org.keycloak.storage.ldap.mappers.LDAPStorageMapper")

jq -c '.[]' "$MAPPER_FILE1" | while read -r mapper; do
  NAME=$(echo "$mapper" | jq -er '.name' 2>/dev/null || echo "UNKNOWN")

  if echo "$EXISTING_MAPPERS_JSON" | jq -e ".[] | select(.name==\"$NAME\")" > /dev/null; then
    echo "✅ Mapper '$NAME' déjà présent pour PingDS."
  else
    RESPONSE=$(curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/components" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(echo "$mapper" | jq --arg parentId "$PINGDS_ID" '. + {parentId: $parentId, providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"}')")

    if echo "$RESPONSE" | grep -q 'error'; then
      echo "❌ Échec de l'ajout du mapper '$NAME'. Réponse : $RESPONSE"
    else
      echo "➕ Mapper '$NAME' ajouté avec succès à PingDS."
    fi
  fi
done


# Adding mappers to LDAP_MT
if [[ ! -f "$MAPPER_FILE2" ]]; then
  echo "❌ Fichier $MAPPER_FILE2 introuvable."
  exit 1
fi

echo "🔍 Vérification et ajout des mappers depuis $MAPPER_FILE2 pour LDAP_MT..."

EXISTING_MAPPERS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components/$LDAP_MT/sub-components?type=org.keycloak.storage.ldap.mappers.LDAPStorageMapper")

jq -c '.[]' "$MAPPER_FILE2" | while read -r mapper; do
  NAME=$(echo "$mapper" | jq -er '.name' 2>/dev/null || echo "UNKNOWN")

  if echo "$EXISTING_MAPPERS_JSON" | jq -e ".[] | select(.name==\"$NAME\")" > /dev/null; then
    echo "✅ Mapper '$NAME' déjà présent pour PingDS."
  else
    RESPONSE=$(curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/components" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(echo "$mapper" | jq --arg parentId "$LDAP_MT" '. + {parentId: $parentId, providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"}')")

    if echo "$RESPONSE" | grep -q 'error'; then
      echo "❌ Échec de l'ajout du mapper '$NAME'. Réponse : $RESPONSE"
    else
      echo "➕ Mapper '$NAME' ajouté avec succès à PingDS."
    fi
  fi
done