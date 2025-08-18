#!/bin/bash
set +H

KEYCLOAK_URL="http://localhost:8080"
REALM="test"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"
USERS_JSON="../users.json"
upadmin_PASSWORD="upadmin"

echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d 'grant_type=password' \
  -d "client_id=$CLIENT_ID" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "❌ Failed to get admin token."
  exit 1
fi

# Charger la liste des groupes existants
GROUPS_JSON=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/groups")

# Extraire l'utilisateur upadmin depuis le JSON
USER=$(jq -c '.[] | select(.username=="upadmin")' "$USERS_JSON")
if [[ -z "$USER" ]]; then
  echo "❌ User upadmin not found in JSON."
  exit 1
fi

USERNAME=$(echo "$USER" | jq -r '.username')
EMAIL=$(echo "$USER" | jq -r '.email')
FIRSTNAME=$(echo "$USER" | jq -r '.firstName')
LASTNAME=$(echo "$USER" | jq -r '.lastName')

# Vérifier si le user existe déjà
EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$USERNAME" | jq -r '.[0].username // empty')

if [[ "$EXISTS" == "$USERNAME" ]]; then
  echo "✅ User '$USERNAME' already exists."
else
  # Créer le user
  echo "➕ Creating user '$USERNAME'..."
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
          \"username\": \"$USERNAME\",
          \"email\": \"$EMAIL\",
          \"firstName\": \"$FIRSTNAME\",
          \"lastName\": \"$LASTNAME\",
          \"enabled\": true
        }"
  echo "✔️ User '$USERNAME' created."
fi

# Récupérer l'ID du user
USER_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$USERNAME" | jq -r '.[0].id')

# Ajouter le user aux groupes
for group in $(echo "$USER" | jq -r '.groups[]'); do
  # Vérifier si le groupe existe
  GROUP_ID=$(echo "$GROUPS_JSON" | jq -r --arg g "$group" '.[] | select(.name==$g) | .id')

  # Créer le groupe si inexistant
  if [[ -z "$GROUP_ID" ]]; then
    echo "⚠️ Group '$group' not found. Creating..."
    RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM/groups" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"name\": \"$group\"}")

    if [[ "$RESPONSE_CODE" != "201" ]]; then
      echo "❌ Failed to create group '$group'. Skipping this group."
      continue
    fi

    # Recharger la liste des groupes après création
    GROUPS_JSON=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/groups")
    GROUP_ID=$(echo "$GROUPS_JSON" | jq -r --arg g "$group" '.[] | select(.name==$g) | .id')
  fi

  # Ajouter l'utilisateur au groupe
  curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/groups/$GROUP_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
  echo "➕ User $USERNAME added to group $group."
done


# Setting password for user upadmin
echo "🔑 Setting password for user upadmin..."

# Récupérer l'ID du user upadmin
USER_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/users?username=upadmin" | jq -r '.[0].id')

if [[ -z "$USER_ID" ]]; then
  echo "❌ Could not find user ID for upadmin."
  exit 1
fi

RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/reset-password" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
        \"temporary\": false,
        \"type\": \"password\",
        \"value\": \"$upadmin_PASSWORD\"
      }")

if [[ "$RESPONSE_CODE" == "204" ]]; then
  echo "✔️ Password set successfully for user '$USERNAME'."
else
  echo "❌ Failed to set password for user '$USERNAME'. HTTP code: $RESPONSE_CODE"
fi

echo "✔️ All done!"