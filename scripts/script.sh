#!/bin/bash
set +H
./delete-realm.sh
./create-realm.sh
# ./cloning-realm-by-realm-jsonfile.sh
./create-upadmin-user.sh
echo "done1"
./creating-user-federation.sh
echo "done2"
./adding-mappers-to-user-federations.sh
echo "done3"
./creating-users.sh
echo "done4"
./creating-roles.sh
echo "done5"
./assigning-roles-to-users.sh
echo "done5"
./creating-client-scopes.sh
echo "done6"
./creating-mappers-of-client-scopes.sh
echo "done7"
./creating-clients.sh
echo "done8"
./adding-client-scope-to-client.sh 
echo "done9"
./adding-client-mappers-in-client-dedicated-mappers.sh         
echo "done10"    
./change-keycloak-theme.sh
echo "done11"

