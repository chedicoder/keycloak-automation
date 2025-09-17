#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
User_Role_FILE="../roles-to-user.json"

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

if [[ ! -f "$User_Role_FILE" ]]; then
  echo "❌ Assigning file $User_Role_FILE not found."
  exit 1
fi

# Parcourir chaque entrée du JSON
jq -c '.[]' "$User_Role_FILE" | while read entry; do
  USER=$(echo "$entry" | jq -r '.user')
  ROLES=$(echo "$entry" | jq -r '.roles[]')

  # Récupérer l'ID de l'utilisateur
  USER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$USER" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" | jq -r '.[0].id')

  if [ "$USER_ID" = "null" ] || [ -z "$USER_ID" ]; then
    echo "❌ Utilisateur $USER introuvable"
    continue
  fi

  echo "👤 Assigning roles to user $USER ($USER_ID)..."

  for ROLE_NAME in $ROLES; do
    # Récupérer l'ID du rôle
    ROLE_INFO=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/roles/$ROLE_NAME" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json")

    if echo "$ROLE_INFO" | jq -e .id > /dev/null 2>&1; then
      ROLE_PAYLOAD=$(echo "$ROLE_INFO" | jq '{id: .id, name: .name}')
      # Assigner le rôle à l’utilisateur
      curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/role-mappings/realm" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "[$ROLE_PAYLOAD]" > /dev/null
      echo "   ✅ Rôle $ROLE_NAME assigné à $USER"
    else
      echo "   ⚠️ Rôle $ROLE_NAME introuvable"
    fi
  done
done
