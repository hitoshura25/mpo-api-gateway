# mpo-api-gateway
Utilizing Istio for implementing a service mesh for Media Player Omega related services

## Running on a local cluster
The following are instructions for deploying to a local cluster via Docker, KinD, and Kubernetes. 

Currently working on a MacBook Pro (16in, M4 Pro, 48gb RAM, OS 15.3.2). Your results may vary.

***Note on LoadBalancer service type***

KinD documents some possible solutions to allow LoadBalancer types of services (which is what the Istio gateway uses by default) to work on the cluster: https://kind.sigs.k8s.io/docs/user/loadbalancer/

However nothing seemed to work for me, perhaps because I'm on a Mac and using Docker Desktop (there may be some additional ports that need to be forwarded). Using help from this article, https://auth0.com/blog/securing-kubernetes-clusters-with-istio-and-auth0/, a workaround is to forward port traffic to the gateway like this:

`kubectl port-forward service/mpo-api-gateway-istio 8080:80`

### Install Necessary Tools
#### Docker
https://www.docker.com/get-started/

#### kind
`brew install kind`

#### kubectl
`brew install kubectl`

#### helm
`brew install helm`

#### bitnami charts (for keycloak)
```
helm repo add bitnami https://charts.bitnami.com/bitnami  
helm repo update 
```

#### Istio
https://istio.io/latest/docs/setup/getting-started/#install

#### Run Scripts

```
# Setup Keycloak Admin Password Env variables in order things to work (below are examples, i.e. if running locally)
export KEYCLOAK_ADMIN_USER="admin"
export KEYCLOAK=ADMIN_PASSWORD="admin"
export KEYCLOAK_URL=http://localhost:8080/auth
export OAUTH_CLIENT_NAME="Media-Player-Omega"
export OAUTH_AUTHORITY="http://localhost:8080/auth/realms/master"
export OAUTH_CLIENT_ID="Media-Player-Omega"
export OAUTH_REDIRECT_URI="http://localhost:8080/frontend/login_callback.html"
export OAUTH_POST_LOGOUT_REDIRECT_URI="http://localhost:8080"

# Setup the cluster, Istio, Kubernetes Gateway CRDs, and deploy the apps and gateway
./scripts/setup.sh

# Setup test users for auth via Keycloak
./scripts/setupKeycloakUsers.sh

# Access the application
curl "http://localhost:8080/frontend"

### To cleanup when done
./scripts/cleanup.sh
```