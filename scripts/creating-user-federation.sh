#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma/auth"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"

PingDS_name="PingDS"
LDAP_name="LDAP_MT"
PING_DS_FILE="../pingds.json"
LDAP_MT_FILE="../ldap_mt.json"

# Get the Pingds bindcredential from secret dirmanager.pw in secrets of pingds ns
K8S_SECRET_URL="https://k8s-dashboard.msictst.iamdg.net.ma/api/v1/secret/pingds/ds-passwords"
TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6ImRPREJhTW00enNENzktcDU1c3JGelFfdEo2ZWdqRlJ2RTJWUFAzSEM5V3MifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlLWRzLWNsdXN0ZXItYWRtaW4tdG9rZW4iLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoia3ViZS1kcy1jbHVzdGVyLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiOGRhNTM3NzgtNGZmNC00YTE4LWEyN2YtMjUxN2M2OTk2NTNmIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmt1YmUtZHMtY2x1c3Rlci1hZG1pbiJ9.iqzaJCNIcj7vZBG44GRezEUd9OLr6_cw-zoSOgJpN4FAPIPh4Y18CEcVKCbN2yelY8_aobO5LKfHtZlmKq6r3iO3BWrW8978sbhjeWeaqiYiXRuqJ-C4uV7MIoaqIrxiocKHMnWAEN66urqmeC5Wkns1ZrJADEx3W4j441tAY8pQaUHpxvsd2HTAw3HMfCjV_lyQqrSJ4DYnkTcE5F8NNfCNQZbQBbOglnjH2Z-1AC2Xz5p-WyJA5UvhZZ7xFQ6piu_e69_yYCIVT5kErLk8oV1W7r1u8yRTVYoIwNTWC2V6XvX4Wz075L3XjKFF0aSpPGukaKdb3fxEmnDg_JLT9g"   # K8S token


if [[ ! -f "$PING_DS_FILE" ]]; then
  echo "File $PING_DS_FILE not found!"
  exit 1
fi

if [[ ! -f "$LDAP_MT_FILE" ]]; then
  echo "File $LDAP_MT_FILE not found!"
  exit 1
fi

DIRMANAGER_PW=$(curl -s -k -X GET -H "Authorization: Bearer $TOKEN" "$K8S_SECRET_URL" \
  | jq -r '.data["dirmanager.pw"]' \
  | base64 --decode)

if [[ -z "$DIRMANAGER_PW" ]]; then
  echo "Error: dirmanager.pw not found"
  exit 1
fi

jq --arg pw "$DIRMANAGER_PW" '.config.bindCredential = [$pw]' "$PING_DS_FILE" > tmp.$$.json && mv tmp.$$.json "$PING_DS_FILE"
echo "✅ bindCredential updated successfully"

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

