#!/bin/bash
set +H
./cloning-realm-by-realm-jsonfile.sh
./create-upadmin-user.sh
./creating-user-federation.sh
./adding-mappers-to-user-federations.sh
./creating-users.sh
./creating-roles.sh
./assigning-roles-to-users.sh
./creating-client_scopes.sh
./creating-mappers-of-client-scopes.sh
./creating-clients.sh
./adding-client-scope-to-client.sh 
./adding-client-mappers-in-client-dedicated-mappers.sh             
./change-keycloak-theme.sh

