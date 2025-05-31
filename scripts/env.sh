#!/bin/bash
if [ -z "$KEYCLOAK_URL" ]; then
  echo "Error: KEYCLOAK_URL env variable is not set. Please set it before running this script." >&2
  exit 1
fi

if [ -z "$KEYCLOAK_ADMIN_USER" ]; then
  echo "Error: KEYCLOAK_ADMIN_USER env variable is not set. Please set it before running this script." >&2
  exit 1
fi

if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
  echo "Error: KEYCLOAK_ADMIN_PASSWORD env variable is not set. Please set it before running this script." >&2
  exit 1
fi

if [ -z "$OAUTH_AUTHORITY" ]; then
  echo "Error: OAUTH_AUTHORITY env variable is not set. Please set it before running this script." >&2
  exit 1
fi

if [ -z "$OAUTH_CLIENT_ID" ]; then
  echo "Error: OAUTH_CLIENT_ID env variable is not set. Please set it before running this script." >&2
  exit 1
fi

if [ -z "$OAUTH_REDIRECT_URI" ]; then
  echo "Error: OAUTH_REDIRECT_URI env variable is not set. Please set it before running this script." >&2
  exit 1
fi

if [ -z "$OAUTH_POST_LOGOUT_REDIRECT_URI" ]; then
  echo "Error: OAUTH_POST_LOGOUT_REDIRECT_URI env variable is not set. Please set it before running this script." >&2
  exit 1
fi

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