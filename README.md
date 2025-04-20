# mpo-api-gateway
Utilizing Istio for implementing a service mesh for Media Player Omega related services

## Running on a local cluster
The following are instructions for deploying to a local cluster via Docker, KinD, and Kubernetes. 

Currently working on a MacBook Pro (16in, M4 Pro, 48gb RAM, OS 15.3.2). Your results may vary.

***Note on LoadBalancer service type***

KinD documents some possible solutions to allow LoadBalancer types of services (which is what the Istio gateway uses by default) to work on the cluster: https://kind.sigs.k8s.io/docs/user/loadbalancer/

However nothing seemed to work for me, perhaps because I'm on a Mac and using Docker Desktop (there may be some additional ports that need to be forwarded). Using help from this article, https://medium.com/groupon-eng/loadbalancer-services-using-kubernetes-in-docker-kind-694b4207575d, I found a workaround was to setup an additional Ingress controller to forward traffic from port 80 on the local host to the Istio gateway service (of type LoadBalancer). The key parts of this in the instructions below:
- The cluster.yaml config file used below contains settings to expose 80 and 443 ports to the control plane
- The **Setup Ingress to forward host traffic to the kind cluster** section details the setup for the Ingress controller to forward to the Istio gateway service

### Install Necessary Tools
#### Docker
https://www.docker.com/get-started/

#### kind
`brew install kind`

#### kubectl
`brew install kubectl`

#### Istio
https://istio.io/latest/docs/setup/getting-started/#install

### Create a kind cluster
`kind create cluster --name=my-cluster --config=k8s/local/cluster.yaml`

### Setup Istio
#### Use minimal Istio profile
`istioctl install --set profile=minimal`

#### Enable automatic side car injection
`kubectl label namespace default istio-injection=enabled`

### Setup Kubernetes Gateway API Custom Resource Definition (CRD)
`kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml`

### Allow LoadBalancer to run on the kind control plan node
`kubectl label node my-cluster-control-plane node.kubernetes.io/exclude-from-external-load-balancers-`

### Deploy apps
`kubectl apply -f k8s/apps`

### Setup gateway
`kubectl apply -f k8s/gateway`

### Setup Ingress to forward host traffic to the kind cluster
#### patch kind to forward the hostPorts to an NGINX ingress controller and schedule it to the control-plane custom labelled node
`kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml`

#### Wait for Ingress to be setup
`kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s`

#### Apply Ingress controller to forward routes to the gateway service
`kubectl apply -f k8s/local/nginx-ingress.yaml`

### Verify the deployment
`kubectl get all`

### Access the application
`curl "http://localhost/search/?term=games"`

### To cleanup when done
`kubectl delete -f k8s/apps`

`kubectl delete -f k8s/gateway`

`kubectl delete -f k8s/local/nginx-ingress.yaml`

`kind delete cluster --name my-cluster`