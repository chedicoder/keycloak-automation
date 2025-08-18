#!/bin/bash
set +H  

KEYCLOAK_URL="http://localhost:8080"
REALM="test"
ADMIN_USER="chedi"
ADMIN_PASS="123456789"
CLIENT_ID="admin-cli"
User_Role_FILE="../role-to-user.json"

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

jq -c '.[]' "$User_Role_FILE" | while read entry; do
  ROLE_NAME=$(echo "$entry" | jq -r '.role')
  USERS=$(echo "$entry" | jq -r '.users[]')

  # Récupérer l'ID du rôle
  ROLE_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/roles/$ROLE_NAME" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json")

  # Vérifier si le rôle existe
  if echo "$ROLE_ID" | jq -e .id > /dev/null 2>&1; then
    echo "✅ Rôle $ROLE_NAME trouvé"
  else
    echo "⚠️ Rôle $ROLE_NAME introuvable"
    continue
  fi

  ROLE_PAYLOAD=$(echo "$ROLE_ID" | jq '{id: .id, name: .name}')

  # Assigner le rôle à chaque user
  for user in $USERS; do
    # Récupérer l'ID de l'utilisateur
    USER_ID=$(curl -s -k -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$user" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" | jq -r '.[0].id')

    if [ "$USER_ID" = "null" ] || [ -z "$USER_ID" ]; then
      echo "❌ Utilisateur $user introuvable"
      continue
    fi

    # Assigner le rôle
    curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/role-mappings/realm" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "[$ROLE_PAYLOAD]"

    echo "🎯 Rôle $ROLE_NAME assigné à $user"
  done
done