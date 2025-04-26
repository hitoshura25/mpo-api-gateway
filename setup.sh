#!/bin/bash
# Create a kind cluster
kind create cluster --name=my-cluster --config=k8s/local/cluster.yaml

# Use minimal Istio profile
istioctl install --set profile=minimal -y

# Enable automatic side car injection
kubectl label namespace default istio-injection=enabled

# Setup Kubernetes Gateway API Custom Resource Definition (CRD)
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# Allow LoadBalancer to run on the kind control plan node
kubectl label node my-cluster-control-plane node.kubernetes.io/exclude-from-external-load-balancers-

# Deploy apps
kubectl apply -f k8s/apps

# Setup gateway
kubectl apply -f k8s/gateway

# Wait for the deployment to be ready
kubectl rollout status deployment mpo-api-gateway-istio -n default --timeout=90s

# Forward traffic from localhost to the gateway
kubectl port-forward service/mpo-api-gateway-istio 8080:80 > /dev/null 2>&1 &