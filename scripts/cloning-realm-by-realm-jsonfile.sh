#!/bin/bash
set +H  

KEYCLOAK_EXPORT_URL="https://app.msicint.iamdg.net.ma/auth"
KEYCLOAK_URL="https://app.msictst.iamdg.net.ma/auth"

export ECM_EOC_PCS_ENV_URL="ecm-eoc-pcs.msicint.iamdg.net.ma"
export APP_ENV_URL="app.msicint.iamdg.net.ma"

REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"


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


# Downloading the dxp realm json file from other keycloak server (exporting)
curl -s -k -X POST \
  "$KEYCLOAK_EXPORT_URL/admin/realms/master/partial-export?exportClients=true&exportGroupsAndRoles=true" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -o dxp-realm-dm.json

# clone dxp realm (importing)
echo "Cloning dxp realm ..."
envsubst < dxp-realm.json > dxp-realm-final.json
curl -s -k -X POST $KEYCLOAK_URL/admin/realms   -H "Authorization: Bearer $ADMIN_TOKEN"   -H "Content-Type: application/json"   --data-binary @dxp-realm-final.json
