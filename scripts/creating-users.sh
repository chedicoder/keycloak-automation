#!/bin/bash
set +H

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
USERS_FILE="../users.json"

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

# Vérifier le fichier JSON
if [[ ! -f "$USERS_FILE" ]]; then
    echo "❌ File $USERS_FILE not found."
    exit 1
fi

# Récupérer tous les groupes existants
GROUPS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/groups")

# Parcourir tous les utilisateurs
jq -c '.[]' "$USERS_FILE" | while read -r user; do
    USERNAME=$(echo "$user" | jq -r '.username')
    EMAIL=$(echo "$user" | jq -r '.email')
    FIRSTNAME=$(echo "$user" | jq -r '.firstName')
    LASTNAME=$(echo "$user" | jq -r '.lastName')
    GROUPS_ARR=($(echo "$user" | jq -r '.groups[]'))

    echo "Creating user $USERNAME..."
    RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
            \"username\": \"$USERNAME\",
            \"email\": \"$EMAIL\",
            \"enabled\": true,
            \"firstName\": \"$FIRSTNAME\",
            \"lastName\": \"$LASTNAME\"
          }")

    if [[ "$RESPONSE_CODE" != "201" ]]; then
        echo "❌ Error creating user $USERNAME (HTTP $RESPONSE_CODE). Skipping."
        continue
    fi

    # Récupérer l'ID utilisateur
    USER_ID=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
        "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$USERNAME" | jq -r '.[0].id')

    for group in "${GROUPS_ARR[@]}"; do
        # Chercher le groupe existant
        GROUP_ID=$(echo "$GROUPS_JSON" | jq -r --arg g "$group" '.[] | select(.name==$g) | .id')

        # Créer le groupe si inexistant
        if [[ -z "$GROUP_ID" ]]; then
            echo "⚠️ Group '$group' not found. Creating..."
            RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/groups" \
              -H "Authorization: Bearer $ADMIN_TOKEN" \
              -H "Content-Type: application/json" \
              -d "{\"name\": \"$group\"}")

            if [[ "$RESPONSE_CODE" != "201" ]]; then
                echo "❌ Failed to create group '$group'. Skipping this group."
                continue
            fi

            # Recharger la liste des groupes après création
            GROUPS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/groups")
            GROUP_ID=$(echo "$GROUPS_JSON" | jq -r --arg g "$group" '.[] | select(.name==$g) | .id')
        fi

        # Ajouter l'utilisateur au groupe
        curl -s -k -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/groups/$GROUP_ID" \
          -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
        echo "➕ User $USERNAME added to group $group."
    done
done

echo "✅ done creating users and adding them to groups."
