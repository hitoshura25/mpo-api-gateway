#!/bin/bash
set -e  # Exit on error
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/env.sh"

# Set the namespace
NAMESPACE="mpo"

# Encode the environment variables in Base64
OAUTH_AUTHORITY_B64=$(echo -n "$OAUTH_AUTHORITY" | base64)
OAUTH_CLIENT_ID_B64=$(echo -n "$OAUTH_CLIENT_ID" | base64)
OAUTH_REDIRECT_URI_B64=$(echo -n "$OAUTH_REDIRECT_URI" | base64)
OAUTH_POST_LOGOUT_REDIRECT_URI_B64=$(echo -n "$OAUTH_POST_LOGOUT_REDIRECT_URI" | base64)

# Generate the Secret YAML file
cat <<EOF > "$SCRIPT_DIR/../k8s/secrets/mpo-frontend.yaml"
apiVersion: v1
kind: Secret
metadata:
  name: mpo-frontend-secret
  namespace: ${NAMESPACE}
type: Opaque
data:
  OAUTH_AUTHORITY: ${OAUTH_AUTHORITY_B64}
  OAUTH_CLIENT_ID: ${OAUTH_CLIENT_ID_B64}
  OAUTH_REDIRECT_URI: ${OAUTH_REDIRECT_URI_B64}
  OAUTH_POST_LOGOUT_REDIRECT_URI: ${OAUTH_POST_LOGOUT_REDIRECT_URI_B64}
EOF