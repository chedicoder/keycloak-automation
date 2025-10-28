#!/bin/bash
set +H

KEYCLOAK_URL="https://app.msicint.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"

PingDS_name="PingDS"
Group_mapper_name="group"

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

echo "🔍 Fetching PingDS provider ID..."
PINGDS_ID=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components?parent=$REALM&type=org.keycloak.storage.UserStorageProvider" \
  | jq -r --arg name "$PingDS_name" '.[] | select(.name == $name) | .id')

if [[ -z "$PINGDS_ID" ]]; then
  echo "❌ LDAP provider '$PingDS_name' not found."
  exit 1
fi
echo "✅ PingDS ID: $PINGDS_ID"

echo "🔍 Fetching group mapper ID by name..."
GROUP_MAPPER_ID=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components?parent=$PINGDS_ID&type=org.keycloak.storage.ldap.mappers.LDAPStorageMapper" \
  | jq -r --arg name "$Group_mapper_name" '.[] | select(.name == $name) | .id')

if [[ -z "$GROUP_MAPPER_ID" ]]; then
  echo "❌ Group mapper named '$Group_mapper_name' not found for PingDS provider."
  exit 1
fi
echo "✅ Group Mapper ID: $GROUP_MAPPER_ID"

echo "🔄 Starting synchronization..."
SYNC_RESULT=$(curl -s -k -X POST \
  "$KEYCLOAK_URL/admin/realms/$REALM/user-storage/$PINGDS_ID/mappers/$GROUP_MAPPER_ID/sync?direction=fedToKeycloak" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json")

echo "✅ Synchronization completed successfully."
echo "📄 Result:"
echo "$SYNC_RESULT" | jq .
