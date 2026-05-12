#!/usr/bin/env bash
set -euo pipefail

echo "Rendering Helm chart..."
helm template widget-api charts/widget-api > rendered.yaml

echo "Running kubeconform..."
kubeconform -strict -summary -ignore-missing-schemas rendered.yaml

echo "Running Kyverno tests..."
kyverno test tests/kyverno

echo "Scanning widget-api image with Trivy..."
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  ghcr.io/stefanprodan/podinfo:6.7.1

echo "Validation complete."