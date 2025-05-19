#!/bin/bash
export KEYCLOAK_URL=http://localhost:8080/auth
export KEYCLOAK_TOKEN=$(curl -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
echo $KEYCLOAK_TOKEN

export CLIENT="Media-Player-Omega"
# Create initial token to register the client
read -r client token <<<$(curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"expiration": 0, "count": 1}' $KEYCLOAK_URL/admin/realms/master/clients-initial-access | jq -r '[.id, .token] | @tsv')

# Register the client
read -r id secret <<<$(curl -X POST -d "{ \"clientId\": \"${CLIENT}\", \"implicitFlowEnabled\": true }" -H "Content-Type:application/json" -H "Authorization: bearer ${token}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default| jq -r '[.id, .secret] | @tsv')

# Add allowed redirect URIs
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT \
  -H "Content-Type: application/json" -d "{\"serviceAccountsEnabled\": true, \"directAccessGrantsEnabled\": true, \"authorizationServicesEnabled\": true, \"redirectUris\": [\"http://localhost:8080/\"]}" $KEYCLOAK_URL/admin/realms/master/clients/${id}

ROLE_NAME="mpo-user"

echo "Creating role read:search-results"
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" \
 -d "{
    \"name\": \"read:search-results\",
    \"description\": \"View Search Results\"
  }" \
$KEYCLOAK_URL/admin/realms/master/clients/${id}/roles

echo "Creating role read:subscriptions"
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" \
 -d "{
    \"name\": \"read:subscriptions\",
    \"description\": \"View Subscriptions\"
  }" \
$KEYCLOAK_URL/admin/realms/master/clients/${id}/roles

echo "Creating composites for ${ROLE_NAME}"
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" \
 -d "{
    \"name\": \"${ROLE_NAME}\",
    \"description\": \"Media Player Omega User\",
    \"composite\": true,
    \"composites\": {
      \"client\": {
        \"${CLIENT}\": [
            \"read:search-results\",
            \"read:subscriptions\"
          ]
        }
    }
}" \
$KEYCLOAK_URL/admin/realms/master/clients/${id}/roles

echo "Creating role-mapper"
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{
       "name": "role-mapper",
       "protocol": "openid-connect",
       "protocolMapper": "oidc-usermodel-realm-role-mapper",
       "config": {
         "claim.name": "roles",
         "jsonType.label": "String",
         "multivalued": "true",
         "id.token.claim": "true",
         "access.token.claim": "true",
         "userinfo.token.claim": "true"
       }
     }' \
     "$KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models"

echo "Creating permissions mapper"
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{
       "name": "permissions-mapper",
       "protocol": "openid-connect",
       "protocolMapper": "oidc-usermodel-attribute-mapper",
       "config": {
         "claim.name": "permissions",
         "jsonType.label": "String",
         "user.attribute": "permissions",
         "id.token.claim": "true",
         "access.token.claim": "true",
         "userinfo.token.claim": "true",
         "multivalued": "true"
       }
     }' \
     "$KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models"

echo 'Add the group attribute in the JWT returned by Keycloak'
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models

echo 'Add the user type attribute in the JWT returned by Keycloak'
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "usertype", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "usertype", "jsonType.label": "String", "user.attribute": "usertype", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models

echo 'Create regular user'
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" \
 -d "{
      \"username\": \"user\", 
      \"email\": \"user@acme.com\", 
      \"enabled\": true, 
      \"credentials\": [
        {
          \"type\": \"password\", 
          \"value\": \"password\", 
          \"temporary\": false
        }
      ]
    }" $KEYCLOAK_URL/admin/realms/master/users

echo 'Get created user ID'
USER_ID=$(curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -X GET "$KEYCLOAK_URL/admin/realms/master/users?email=user%40acme.com" | jq -r '.[0].id')

echo 'Get client role ID'
CLIENT_ROLE_ID=$(curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -X GET "$KEYCLOAK_URL/admin/realms/master/clients/${id}/roles/${ROLE_NAME}" | jq -r '.id')

echo 'Assign client role to user'
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -X POST -H "Content-Type: application/json" \
  -d "[{
    \"id\": \"${CLIENT_ROLE_ID}\",
    \"name\": \"${ROLE_NAME}\"
  }]" "$KEYCLOAK_URL/admin/realms/master/users/${USER_ID}/role-mappings/clients/${id}" 