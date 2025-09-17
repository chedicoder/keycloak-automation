#!/bin/bash
set +H

KEYCLOAK_URL="http://localhost:8080"
REALM="master"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"
GROUPS_FILE="../groups.txt"   # fichier contenant un groupe par ligne
admx_PASSWORD="admx"

echo "🔑 Getting admin token..."
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

# Vérifier le fichier de groupes
if [[ ! -f "$GROUPS_FILE" ]]; then
    echo "❌ File $GROUPS_FILE not found."
    exit 1
fi

echo "📂 Creating groups from $GROUPS_FILE ..."
while IFS= read -r GROUP; do
    # ignorer les lignes vides ou commentaires
    [[ -z "$GROUP" || "$GROUP" =~ ^# ]] && continue

    echo "➡️ Creating group: $GROUP"

    # Vérifier si le groupe existe déjà
    EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
      "$KEYCLOAK_URL/admin/realms/$REALM/groups?search=$GROUP" | jq -r '.[].name' | grep -x "$GROUP")

    if [[ "$EXISTS" == "$GROUP" ]]; then
        echo "⚠️ Group '$GROUP' already exists, skipping."
        continue
    fi

    # Créer le groupe
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$KEYCLOAK_URL/admin/realms/$REALM/groups" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"name\": \"$GROUP\"}")

    if [[ "$RESPONSE" == "201" ]]; then
        echo "✅ Group '$GROUP' created."
    else
        echo "❌ Failed to create group '$GROUP' (HTTP $RESPONSE)"
    fi
done < "$GROUPS_FILE"
