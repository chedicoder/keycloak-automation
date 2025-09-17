#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
ROLES_FILE="../roles.json"

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

if [[ ! -f "$ROLES_FILE" ]]; then
  echo "❌ Roles file $ROLES_FILE not found."
  exit 1
fi

jq -c '.[]' "$ROLES_FILE" | while read role; do
  NAME=$(echo $role | jq -r '.name')
  DESCRIPTION=$(echo $role | jq -r '.description')

  # Vérifier si le rôle existe déjà
  EXISTS=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/roles/$NAME" | jq -r '.name // empty')

  if [ "$EXISTS" == "$NAME" ]; then
    echo "✅ Role '$NAME' exists already, skipping."
  else
    echo "➕ Creating role '$NAME'..."

    curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/roles" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"$NAME\",
        \"description\": \"$DESCRIPTION\"
      }"

    echo "✔️ Role '$NAME' is created successfully"
  fi
done
