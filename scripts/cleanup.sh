#!/bin/bash
kubectl delete -f k8s/apps
kubectl delete -f k8s/gateway
kubectl delete -f k8s/security
kind delete cluster --name my-cluster