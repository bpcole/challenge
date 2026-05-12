#!/usr/bin/env bash
set -euo pipefail

echo "Testing from allowed frontend namespace..."
kubectl run curl-frontend \
  -n frontend \
  --image=curlimages/curl:8.6.0 \
  --restart=Never \
  --rm -it \
  -- curl -sS http://widget-api.widget-api.svc.cluster.local:9898

echo "Testing from blocked namespace..."
kubectl create namespace blocked --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace blocked istio-injection=enabled --overwrite

kubectl run curl-blocked \
  -n blocked \
  --image=curlimages/curl:8.6.0 \
  --restart=Never \
  --rm -it \
  -- curl -sS -m 5 http://widget-api.widget-api.svc.cluster.local:9898 || true