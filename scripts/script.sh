#!/bin/bash
set +H
./delete-realm.sh
./create-realm.sh
# ./cloning-realm-by-realm-jsonfile.sh
./create-upadmin-user.sh
./creating-user-federation.sh
./adding-mappers-to-user-federations.sh
./synchronise-pingds-groups-to-keycloak.sh
./creating-users.sh
./creating-roles.sh
./assigning-roles-to-user.sh
./creating-client-scopes.sh
./adding-mappers-of-client-scopes.sh
./creating-clients.sh
./adding-client-scopes-to-clients.sh 
./adding-client-mappers-in-client-dedicated-mappers.sh         
./change-keycloak-theme.sh
./create-authentification-flow.sh
./bind-browser-authentication-flow.sh

