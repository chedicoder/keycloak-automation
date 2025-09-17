#!/bin/bash
set +H  

KEYCLOAK_URL="https://app.msicdev.iamdg.net.ma"
REALM="dxp"
ADMIN_USER="admin"
ADMIN_PASS="Password!123"
CLIENT_ID="admin-cli"
# Get the Pingds bindcredential from secret dirmanager.pw in secrets of pingds ns

PingDS_name="PingDS"
LDAP_name="LDAP_MT"


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
  -d '{
    "providerId": "ldap",
    "providerType": "org.keycloak.storage.UserStorageProvider",
    "name": "PingDS",
    "config": {
        "enabled": [
            "false"
        ],
        "vendor": [
            "rhds"
        ],
        "connectionUrl": [
            "ldap://ds-idrepo.pingds:1389"
        ],
        "startTls": [
            "false"
        ],
        "useTruststoreSpi": [
            "always"
        ],
        "connectionPooling": [
            "true"
        ],
        "connectionTimeout": [
            ""
        ],
        "authType": [
            "simple"
        ],
        "bindDn": [
            "uid=admin"
        ],
        "bindCredential": [
            "CocjtHLIOqaMrECD2QV2SxMQXzaW85fU"
        ],
        "editMode": [
            "WRITABLE"
        ],
        "usersDn": [
            "ou=people,ou=identities"
        ],
        "usernameLDAPAttribute": [
            "uid"
        ],
        "rdnLDAPAttribute": [
            "uid"
        ],
        "uuidLDAPAttribute": [
            "entryUUID"
        ],
        "userObjectClasses": [
            "inetuser,iplanet-am-auth-configuration-service,iplanet-am-managed-person,iplanet-am-user-service,iPlanetPreferences,organizationalperson,sunAMAuthAccountLockout,sunFMSAML2NameIdentifier,deviceProfilesContainer,webauthnDeviceProfilesContainer,top,person,inetOrgPerson,msicUser"
        ],
        "customUserSearchFilter": [
            ""
        ],
        "searchScope": [
            "1"
        ],
        "readTimeout": [
            ""
        ],
        "pagination": [
            "true"
        ],
        "referral": [
            ""
        ],
        "importEnabled": [
            "true"
        ],
        "syncRegistrations": [
            "true"
        ],
        "batchSizeForSync": [
            ""
        ],
        "allowKerberosAuthentication": [
            "false"
        ],
        "useKerberosForPasswordAuthentication": [
            "false"
        ],
        "cachePolicy": [
            "DEFAULT"
        ],
        "usePasswordModifyExtendedOp": [
            "false"
        ],
        "validatePasswordPolicy": [
            "false"
        ],
        "trustEmail": [
            "false"
        ],
        "connectionTrace": [
            "false"
        ],
        "changedSyncPeriod": [
            "-1"
        ],
        "fullSyncPeriod": [
            "-1"
        ]
    }
    }'  | grep -oE '[a-f0-9-]{36}'


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
  -d '{
    "providerId": "ldap",
    "providerType": "org.keycloak.storage.UserStorageProvider",
    "name": "LDAP_MT",
    "config": {
        "enabled": [
            "false"
        ],
        "vendor": [
            "ad"
        ],
        "connectionUrl": [
            "ldaps://alirfanedc2.iamdg.net.ma:636"
        ],
        "startTls": [
            "false"
        ],
        "useTruststoreSpi": [
            "always"
        ],
        "connectionPooling": [
            "true"
        ],
        "connectionTimeout": [
            ""
        ],
        "authType": [
            "simple"
        ],
        "bindDn": [
            "uid=admin"
        ],
        "bindCredential": [
            "sso$modernSic*25"
        ],
        "editMode": [
            "READ_ONLY"
        ],
        "usersDn": [
            "DC=iamdg,DC=net,DC=ma"
        ],
        "usernameLDAPAttribute": [
            "sAMAccountName"
        ],
        "rdnLDAPAttribute": [
            "cn"
        ],
        "uuidLDAPAttribute": [
            "objectGUID"
        ],
        "userObjectClasses": [
            "person,organizationalPerson,user"
        ],
        "customUserSearchFilter": [
            "(sAMAccountName=*)"
        ],
        "searchScope": [
            "1"
        ],
        "readTimeout": [
            ""
        ],
        "pagination": [
            "true"
        ],
        "referral": [
            ""
        ],
        "importEnabled": [
            "true"
        ],
        "syncRegistrations": [
            "true"
        ],
        "batchSizeForSync": [
            ""
        ],
        "allowKerberosAuthentication": [
            "false"
        ],
        "useKerberosForPasswordAuthentication": [
            "false"
        ],
        "cachePolicy": [
            "DEFAULT"
        ],
        "usePasswordModifyExtendedOp": [
            "false"
        ],
        "validatePasswordPolicy": [
            "false"
        ],
        "trustEmail": [
            "false"
        ],
        "connectionTrace": [
            "false"
        ],
        "changedSyncPeriod": [
            "-1"
        ],
        "fullSyncPeriod": [
            "-1"
        ]
    }
    }' | grep -oE '[a-f0-9-]{36}'

# Test if LDAP_MT was created successfully
LDAP_MT=$(curl -s -k -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/components?parent=$REALM&type=org.keycloak.storage.UserStorageProvider" \
  | jq -r --arg name "$LDAP_name" '.[] | select(.name == $name) | .id')
if [[ -z "$LDAP_MT" ]]; then
  echo "Failed to create LDAP_MT provider."
  exit 1
fi

