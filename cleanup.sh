#!/bin/bash
kubectl delete -f k8s/apps
kubectl delete -f k8s/gateway
kind delete cluster --name my-cluster