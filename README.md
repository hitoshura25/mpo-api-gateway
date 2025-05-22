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

#### Istio
https://istio.io/latest/docs/setup/getting-started/#install

### Setup the cluster, Istio, Kubernetes Gateway CRDs, and deploy the apps and gateway
`./scripts/setup.sh`

### Setup test users for auth via Keycloak
`./scripts/keycloak/setupKeycloakUsers.sh`

### Access the application
`curl "http://localhost:8080/search/?term=games"`

### To cleanup when done
`./scripts/cleanup.sh`