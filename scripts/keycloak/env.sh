#!/bin/bash
export KEYCLOAK_URL=http://localhost:8080/auth
export REDIRECT_URI=http://localhost:8080/
export ADMIN_USER="admin"
export ADMIN_PASSWORD="admin"
export CLIENT_NAME="Media-Player-Omega"

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