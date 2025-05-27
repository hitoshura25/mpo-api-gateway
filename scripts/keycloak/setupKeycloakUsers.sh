#!/bin/bash
set -e  # Exit on error
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/env.sh"

MAX_RETRIES=3
RETRY_INTERVAL=5

retry_get_admin_token() {
    local attempt=1
    local token=""
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log "Attempting to get admin token (attempt $attempt of $MAX_RETRIES)..."
        token=$(curl -s -d "client_id=admin-cli" \
             -d "username=$KEYCLOAK_ADMIN_USER" \
             -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
             -d "grant_type=password" \
             "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
        
        if [ "$token" != "null" ] && [ ! -z "$token" ]; then
            echo "$token"
            return 0
        fi
        
        log "Failed to get admin token, retrying in $RETRY_INTERVAL seconds..."
        sleep $((RETRY_INTERVAL * attempt))
        attempt=$((attempt + 1))
    done
    
    log "Failed to get admin token after $MAX_RETRIES attempts"
    return 1
}

get_admin_token() {
    log "Getting admin token..."
    retry_get_admin_token || exit 1
}

create_client() {
    local token=$1
    log "Creating initial access token..."
    read -r client init_token <<<$(curl -s -H "Authorization: Bearer ${token}" \
        -X POST -H "Content-Type: application/json" \
        -d '{"expiration": 0, "count": 1}' \
        "$KEYCLOAK_URL/admin/realms/master/clients-initial-access" | jq -r '[.id, .token] | @tsv')

    log "Registering client ${CLIENT_NAME}..."
    read -r client_id client_secret <<<$(curl -s -X POST \
        -d "{ \"clientId\": \"${CLIENT_NAME}\", \"implicitFlowEnabled\": true }" \
        -H "Content-Type:application/json" \
        -H "Authorization: bearer ${init_token}" \
        "${KEYCLOAK_URL}/realms/master/clients-registrations/default" | jq -r '[.id, .secret] | @tsv')

    curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT \
        -H "Content-Type: application/json" \
        -d "{
                \"serviceAccountsEnabled\": true, 
                \"directAccessGrantsEnabled\": true, 
                \"authorizationServicesEnabled\": true, 
                \"fullScopeAllowed\": false,
                \"redirectUris\": [\"${REDIRECT_URI}\"],
                \"defaultRoles\": [],
                \"publicClient\": true
            }" $KEYCLOAK_URL/admin/realms/master/clients/${client_id}

    printf "%s\n" "${client_id}" "${client_secret}"
}

create_permission() {
    local token=$1
    local client_id=$2
    local permission=$3
    local description=$4

    log "Creating permission ${permission}..."
    curl -s -H "Authorization: Bearer ${token}" \
      -X POST -H "Content-Type: application/json" \
      -d "{\"name\": \"${permission}\", \"description\": \"${description}\"}" \
      "$KEYCLOAK_URL/admin/realms/master/clients/${client_id}/roles"
}

create_role_with_permissions() {
    local token=$1
    local client_id=$2
    local role_name=$3
    local -a permissions=("${!4}")
    local permissions_string=$(printf "\"%s\"," "${permissions[@]}" | sed 's/,$//')

    log "Creating role ${role_name} with permissions: ${permissions_string}"
    curl -H "Authorization: Bearer ${token}" -X POST -H "Content-Type: application/json" \
    -d "{
        \"name\": \"${role_name}\",
        \"description\": \"Media Player Omega User\",
        \"composite\": true,
        \"composites\": {
          \"client\": {
            \"${CLIENT_NAME}\": [${permissions_string}]
          }
        }
    }" $KEYCLOAK_URL/admin/realms/master/clients/${client_id}/roles
}

create_user() {
    local token=$1
    local email=$2
    local password=$3
    log "Creating user ${email}..."
    curl -H "Authorization: Bearer ${token}" -X POST -H "Content-Type: application/json" \
    -d "{
          \"username\": \"${email}\", 
          \"email\": \"${email}\", 
          \"enabled\": true, 
          \"credentials\": [
            {
              \"type\": \"password\", 
              \"value\": \"${password}\", 
              \"temporary\": false
            }
          ]
        }" $KEYCLOAK_URL/admin/realms/master/users
}

assign_user_role() {
    local token=$1
    local client_id=$2
    local email=$3
    local role_name=$4

    log "Getting user id for user ${email}..."
    local user_id=$(curl -H "Authorization: Bearer ${token}" \
        -X GET "$KEYCLOAK_URL/admin/realms/master/users?email=$(urlencode "$email")" | jq -r '.[0].id')

    log "Getting role id for role ${role_name}..."
    local role_id=$(curl -s -H "Authorization: Bearer ${token}" \
        -X GET "$KEYCLOAK_URL/admin/realms/master/clients/${client_id}/roles/${role_name}" | jq -r '.id')

    log "Assigning role ${role_name} to user ${email}..."
    curl -s -H "Authorization: Bearer ${token}" \
         -X POST -H "Content-Type: application/json" \
         -d "[{\"id\": \"${role_id}\", \"name\": \"${role_name}\"}]" \
         "$KEYCLOAK_URL/admin/realms/master/users/${user_id}/role-mappings/clients/${client_id}"
}

setup_token_claims() {
    local token=$1
    local client_id=$2
    
    log "Creating client-role-mapper"
    curl -H "Authorization: Bearer ${token}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"client-role-mapper\",
            \"protocol\": \"openid-connect\",
            \"protocolMapper\": \"oidc-usermodel-client-role-mapper\",
            \"config\": {
                \"claim.name\": \"permissions\",
                \"jsonType.label\": \"String\",
                \"client.id\": \"$CLIENT_NAME\",
                \"usermodel.clientRoleMapping.clientId\": \"$CLIENT_NAME\",
                \"multivalued\": \"true\",
                \"id.token.claim\": \"true\",
                \"access.token.claim\": \"true\",
                \"userinfo.token.claim\": \"true\",
                \"usermodel.realm.roles\": \"false\"
            }
        }" \
        "$KEYCLOAK_URL/admin/realms/master/clients/${client_id}/protocol-mappers/models"
}

main() {
    log "Starting Keycloak setup..."
    KEYCLOAK_TOKEN=$(get_admin_token)
    local client_info=$(create_client "$KEYCLOAK_TOKEN")
    IFS='|' read -r -a client_info_array <<< "$client_info"
    local CLIENT_ID="${client_info_array[0]}"
    local CLIENT_SECRET="${client_info_array[1]}"

    create_permission "$KEYCLOAK_TOKEN" "$CLIENT_ID" "read:search-results" "View Search Results"
    create_permission "$KEYCLOAK_TOKEN" "$CLIENT_ID" "read:subscriptions" "View Subscriptions"
        
    local permissions=("read:search-results" "read:subscriptions")
    create_role_with_permissions "$KEYCLOAK_TOKEN" "$CLIENT_ID" "mpo-user" permissions[@]
    
    create_user "$KEYCLOAK_TOKEN" "user@acme.com" "password"
    assign_user_role "$KEYCLOAK_TOKEN" "$CLIENT_ID" "user@acme.com" "mpo-user"
    setup_token_claims "$KEYCLOAK_TOKEN" "$CLIENT_ID"
    log "Setup completed successfully"
}

main "$@"