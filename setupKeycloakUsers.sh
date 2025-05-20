#!/bin/bash
set -e  # Exit on error
KEYCLOAK_URL=http://localhost:8080/auth
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"
CLIENT_NAME="Media-Player-Omega"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o
    
    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

get_admin_token() {
    log "Getting admin token..."
    local token=$(curl -s -d "client_id=admin-cli" \
         -d "username=$ADMIN_USER" \
         -d "password=$ADMIN_PASSWORD" \
         -d "grant_type=password" \
         "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
    echo "$token"
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

    echo "$client_id"
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
    log "Creating role-mapper"
    curl -H "Authorization: Bearer ${token}" \
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
        "$KEYCLOAK_URL/admin/realms/master/clients/${client_id}/protocol-mappers/models"

    log "Creating permissions mapper"
    curl -H "Authorization: Bearer ${token}" \
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
        "$KEYCLOAK_URL/admin/realms/master/clients/${client_id}/protocol-mappers/models"
}

# Main execution
main() {
    log "Starting Keycloak setup..."
    
    KEYCLOAK_TOKEN=$(get_admin_token)
    CLIENT_ID=$(create_client "$KEYCLOAK_TOKEN")

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