#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
# Get the Pingds bindcredential from secret dirmanager.pw in secrets of pingds ns

PingDS_name="PingDS"
LDAP_name="LDAP_MT"
PING_DS_FILE="../pingds.json"
LDAP_MT_FILE="../ldap_mt.json"

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

if [[ ! -f "$PING_DS_FILE" ]]; then
  echo "File $PING_DS_FILE not found!"
  exit 1
fi

if [[ ! -f "$LDAP_MT_FILE" ]]; then
  echo "File $LDAP_MT_FILE not found!"
  exit 1
fi


# Creating PingDS as LDAP provider
echo "Creating PingDS as LDAP provider..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/components" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary @$PING_DS_FILE | grep -oE '[a-f0-9-]{36}'


# Test if PingDS was created successfully
PINGDS_ID=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components?parent=$REALM&type=org.keycloak.storage.UserStorageProvider" \
  | jq -r --arg name "$PingDS_name" '.[] | select(.name == $name) | .id')

if [[ -z "$PINGDS_ID" ]]; then
  echo "Failed to create PingDS provider."
  exit 1
fi

# Creating LDAP_MT as LDAP provider...
echo "Creating LDAP_MT as LDAP provider..."
curl -s -k -X POST "$KEYCLOAK_URL/admin/realms/$REALM/components" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary @$LDAP_MT_FILE | grep -oE '[a-f0-9-]{36}'

# Test if LDAP_MT was created successfully
LDAP_MT=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components?parent=$REALM&type=org.keycloak.storage.UserStorageProvider" \
  | jq -r --arg name "$LDAP_name" '.[] | select(.name == $name) | .id')
if [[ -z "$LDAP_MT" ]]; then
  echo "Failed to create LDAP_MT provider."
  exit 1
fi

