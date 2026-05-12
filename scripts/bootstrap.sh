#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="widget-platform"

echo "Creating kind cluster if needed..."
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  kind create cluster --config clusters/kind-config.yaml
else
  echo "Cluster ${CLUSTER_NAME} already exists."
fi

echo "Adding Helm repos..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Installing Istio..."
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install istio-base istio/base \
  -n istio-system \
  --wait

helm upgrade --install istiod istio/istiod \
  -n istio-system \
  --wait

echo "Installing Kyverno..."
kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kyverno kyverno/kyverno \
  -n kyverno \
  --wait

echo "Waiting for Kyverno..."
kubectl wait --for=condition=available deployment/kyverno-admission-controller \
  -n kyverno --timeout=180s || true

echo "Applying Kyverno policies..."
kubectl apply -f policies/

echo "Installing kube-prometheus-stack..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.service.type=ClusterIP \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --wait

echo "Creating frontend namespace..."
kubectl create namespace frontend --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace frontend tier=frontend --overwrite
kubectl label namespace frontend istio-injection=enabled --overwrite

echo "Deploying widget-api..."
helm upgrade --install widget-api charts/widget-api \
  -n widget-api \
  --wait

echo "Bootstrap complete."
kubectl get pods -A