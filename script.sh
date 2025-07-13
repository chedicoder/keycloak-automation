#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msictst.iamdg.net.ma"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
MAPPER_FILE1="PingDS-mappers.json"
MAPPER_FILE2="LDAP-MT-mappers.json"
PingDS_name="PingDS1"
LDAP_name="LDAP_MT"
USERS_FILE="users.json"
CLIENTS_FILE="clients.json"


# Getting admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -k -X POST "$KEYCLOAK_URL/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d 'grant_type=password' \
  -d "client_id=$CLIENT_ID" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "Failed to get admin token."
  exit 1
fi

# Creating user federations
echo "Creating PingDS as LDAP provider..."
curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/components" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$PingDS_name"'",
    "providerId": "ldap",
    "providerType": "org.keycloak.storage.UserStorageProvider",
    "parentId": "'"$REALM"'",
    "config": {
      "pagination": ["true"],
      "fullSyncPeriod": ["-1"],
      "connectionPooling": ["true"],
      "usersDn": ["ou=people,ou=identities"],
      "cachePolicy": ["NO_CACHE"],
      "useKerberosForPasswordAuthentication": ["false"],
      "importEnabled": ["true"],
      "enabled": ["true"],
      "usernameLDAPAttribute": ["uid"],
      "bindCredential": ["m2CFxdLJpZDFAZTUReNDOXlK3Lc8BKpA"],
      "changedSyncPeriod": ["-1"],
      "bindDn": ["uid=admin"],
      "vendor": ["rhds"],
      "uuidLDAPAttribute": ["entryUUID"],
      "allowKerberosAuthentication": ["false"],
      "connectionUrl": ["ldap://ds-idrepo.pingds:1389"],
      "syncRegistrations": ["true"],
      "authType": ["simple"],
      "debug": ["false"],
      "searchScope": ["1"],
      "useTruststoreSpi": ["ldapsOnly"],
      "priority": ["5"],
      "trustEmail": ["false"],
      "userObjectClasses": ["inetuser,iplanet-am-auth-configuration-service,iplanet-am-managed-person,iplanet-am-user-service,iPlanetPreferences,organizationalperson,sunAMAuthAccountLockout,sunFMSAML2NameIdentifier,deviceProfilesContainer,webauthnDeviceProfilesContainer,top,person,inetOrgPerson"],
      "rdnLDAPAttribute": ["uid"],
      "editMode": ["WRITABLE"],
      "validatePasswordPolicy": ["false"],
      "batchSizeForSync": ["1000"]
    }
  }' | grep -oE '[a-f0-9-]{36}'

PINGDS_ID=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/$REALM/components?parent=$REALM&type=org.keycloak.storage.UserStorageProvider" \
  | jq -r --arg name "$PingDS_name" '.[] | select(.name == $name) | .id')

if [[ -z "$PINGDS_ID" ]]; then
  echo "Failed to create PingDS provider."
  exit 1
fi

echo "Creating LDAP_MT as LDAP provider..."
curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/components" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "LDAP_MT",
    "providerId": "ldap",
    "providerType": "org.keycloak.storage.UserStorageProvider",
    "parentId": "'"$REALM"'",
    "config": {
      "pagination": ["true"],
      "fullSyncPeriod": ["-1"],
      "connectionPooling": ["true"],
      "usersDn": ["DC=iamdg,DC=net,DC=ma"],
      "cachePolicy": ["NO_CACHE"],
      "useKerberosForPasswordAuthentication": ["false"],
      "importEnabled": ["true"],
      "enabled": ["true"],
      "usernameLDAPAttribute": ["sAMAccountName"],
      "bindCredential": ["sso$modernSic*25"],
      "changedSyncPeriod": ["-1"],
      "bindDn": ["CN=ssoModernisationSic,OU=ComptesApplicatifs,DC=iamdg,DC=net,DC=ma"],
      "vendor": ["ad"],
      "uuidLDAPAttribute": ["objectGUID"],
      "allowKerberosAuthentication": ["false"],
      "connectionUrl": ["ldaps://alirfanedc2.iamdg.net.ma:636"],
      "syncRegistrations": ["true"],
      "authType": ["simple"],
      "debug": ["false"],
      "searchScope": ["1"],
      "useTruststoreSpi": ["ldapsOnly"],
      "priority": ["1"],
      "trustEmail": ["false"],
      "userObjectClasses": ["person,organizationalPerson,user"],
      "rdnLDAPAttribute": ["cn"],
      "customUserSearchFilter": ["(sAMAccountName=*)"],
      "editMode": ["READ_ONLY"],
      "validatePasswordPolicy": ["false"],
      "batchSizeForSync": ["1000"]
    }
  }' | grep -oE '[a-f0-9-]{36}'

LDAP_MT=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/$REALM/components?parent=$REALM&type=org.keycloak.storage.UserStorageProvider" \
  | jq -r --arg name "$LDAP_name" '.[] | select(.name == $name) | .id')


if [[ -z "$LDAP_MT" ]]; then
  echo "Failed to create LDAP_MT provider."
  exit 1
fi


# Adding mappers to PingDS
if [[ ! -f "$MAPPER_FILE1" ]]; then
  echo "❌ Fichier $MAPPER_FILE1 introuvable."
  exit 1
fi

echo "🔍 Vérification et ajout des mappers depuis $MAPPER_FILE1 pour PingDS..."

EXISTING_MAPPERS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/$REALM/components/$PINGDS_ID/sub-components?type=org.keycloak.storage.ldap.mappers.LDAPStorageMapper")

jq -c '.[]' "$MAPPER_FILE1" | while read -r mapper; do
  NAME=$(echo "$mapper" | jq -er '.name' 2>/dev/null || echo "UNKNOWN")

  if echo "$EXISTING_MAPPERS_JSON" | jq -e ".[] | select(.name==\"$NAME\")" > /dev/null; then
    echo "✅ Mapper '$NAME' déjà présent pour PingDS."
  else
    RESPONSE=$(curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/components" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(echo "$mapper" | jq --arg parentId "$PINGDS_ID" '. + {parentId: $parentId, providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"}')")

    if echo "$RESPONSE" | grep -q 'error'; then
      echo "❌ Échec de l'ajout du mapper '$NAME'. Réponse : $RESPONSE"
    else
      echo "➕ Mapper '$NAME' ajouté avec succès à PingDS."
    fi
  fi
done


# Adding mappers to LDAP_MT
if [[ ! -f "$MAPPER_FILE2" ]]; then
  echo "❌ Fichier $MAPPER_FILE2 introuvable."
  exit 1
fi

echo "🔍 Vérification et ajout des mappers depuis $MAPPER_FILE2 pour LDAP_MT..."

EXISTING_MAPPERS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/$REALM/components/$LDAP_MT/sub-components?type=org.keycloak.storage.ldap.mappers.LDAPStorageMapper")

jq -c '.[]' "$MAPPER_FILE2" | while read -r mapper; do
  NAME=$(echo "$mapper" | jq -er '.name' 2>/dev/null || echo "UNKNOWN")

  if echo "$EXISTING_MAPPERS_JSON" | jq -e ".[] | select(.name==\"$NAME\")" > /dev/null; then
    echo "✅ Mapper '$NAME' déjà présent pour PingDS."
  else
    RESPONSE=$(curl -s -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/components" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(echo "$mapper" | jq --arg parentId "$LDAP_MT" '. + {parentId: $parentId, providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"}')")

    if echo "$RESPONSE" | grep -q 'error'; then
      echo "❌ Échec de l'ajout du mapper '$NAME'. Réponse : $RESPONSE"
    else
      echo "➕ Mapper '$NAME' ajouté avec succès à PingDS."
    fi
  fi
done

# Adding users
echo "Adding users ..."
if [[ ! -f "$USERS_FILE" ]]; then
  echo "❌ Fichier $USERS_FILE introuvable."
  exit 1
fi

echo "Getting groups list ..."
GROUPS_JSON=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/auth/admin/realms/$REALM/groups")

jq -c '.[]' "$USERS_FILE" | while read -r user; do
  USERNAME=$(echo "$user" | jq -r '.username')
  EMAIL=$(echo "$user" | jq -r '.email')
  FIRSTNAME=$(echo "$user" | jq -r '.firstName')
  LASTNAME=$(echo "$user" | jq -r '.lastName')
  GROUPS_ARR=($(echo "$user" | jq -r '.groups[]'))

  echo "Creating user $USERNAME..."

  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/users" \
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

  USER_ID=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/auth/admin/realms/$REALM/users?username=$USERNAME" | jq -r '.[0].id')
      
  for group in "${GROUPS_ARR[@]}"; do
    GROUP_ID=$(echo "$GROUPS_JSON" | jq -r --arg g "$group" '.[] | select(.name==$g) | .id')

    if [[ -z "$GROUP_ID" ]]; then
      echo "⚠️ Group '$group' not found for user $USERNAME, skipping."
      continue
    fi

    curl -s -k -X PUT "$KEYCLOAK_URL/auth/admin/realms/$REALM/users/$USER_ID/groups/$GROUP_ID" \
      -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null

    echo "➕ User $USERNAME added to group $group."
  done

done
# Adding clients
echo "Adding clients ..."
if [[ ! -f "$CLIENTS_FILE" ]]; then
  echo "❌ Clients file $CLIENTS_FILE not found."
  exit 1
fi

echo "Creating clients ..."

jq -c '.[]' "$CLIENTS_FILE" | while read -r client; do
  CLIENT_ID_VALUE=$(echo "$client" | jq -r '.clientId')

  EXISTS=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/auth/admin/realms/$REALM/clients?clientId=$CLIENT_ID_VALUE" | jq length)

  if [[ "$EXISTS" -gt 0 ]]; then
    echo "⚠️ Client '$CLIENT_ID_VALUE' already exists, skipping."
    continue
  fi

  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$client")

  if [[ "$RESPONSE_CODE" == "201" ]]; then
    echo "➕ Client '$CLIENT_ID_VALUE' created successfully."
  fi  
done    


echo "done"