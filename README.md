# Widget API Platform Challenge

## Overview

This project deploys a hardened `widget-api` workload to a local Kubernetes platform using:

- kind
- Helm
- Istio
- Kyverno
- Prometheus
- Grafana
- GitHub Actions

The application image used is:

```text
ghcr.io/stefanprodan/podinfo:6.7.1
```

The platform demonstrates:

- service mesh traffic control
- mTLS enforcement
- namespace-based authorization
- policy enforcement with Kyverno
- observability with Prometheus/Grafana
- CI validation and security scanning

---

# Architecture

## Platform Components

| Component | Purpose |
|---|---|
| kind | Local Kubernetes cluster |
| Helm | Application packaging and deployment |
| Istio | Service mesh and AuthorizationPolicy enforcement |
| Kyverno | Admission control and policy validation |
| kube-prometheus-stack | Metrics, alerting, and dashboards |
| Trivy | Container vulnerability scanning |
| kubeconform | Kubernetes manifest validation |

---

# Design Decisions

## Why kind

I chose kind because it is lightweight, reproducible, easy to reset during testing, and integrates well with local WSL development.

---

## Why Istio Sidecars

I opted for sidecar Istio injection for easier troubleshooting due to explicit logging and visible proxy behavior.

---

## Pod Security Standards Tradeoff

During testing, I discovered that strict `enforce=restricted` Pod Security Standards conflicted with Istio sidecar initialization because the `istio-init` container requires elevated networking capabilities.

For the challenge timeframe, I used:

```text
pod-security.kubernetes.io/audit=restricted
pod-security.kubernetes.io/warn=restricted
```

while documenting the tradeoff.

If I had more time, I would move Istio to CNI mode so fully enforced restricted PSS could remain enabled without sidecar conflicts.

---

# Security Controls

## Istio AuthorizationPolicy

Traffic is restricted by namespace.

Validated behavior:

| Namespace | Result |
|---|---|
| frontend | allowed |
| blocked | denied |

Validation command:

```bash
./scripts/test-access.sh
```

Expected denied output:

```text
RBAC: access denied
```

---

## Kyverno Policies

Implemented policies:

### disallow-latest-tag

Rejects images using:

```text
:latest
```

### restrict-image-registries

Restricts application images to approved registries within the `widget-api` namespace.

---

# Observability

## ServiceMonitor

A `ServiceMonitor` was configured for `widget-api`.

Location:

```text
charts/widget-api/templates/servicemonitor.yaml
```

---

## Grafana Dashboard

Custom dashboard JSON:

```text
dashboards/widget-api-dashboard.json
```

Dashboard includes:

- request rate
- latency metrics
- pod count
- error-rate visualization

Screenshots are stored under:

```text
screenshots/
```

---

## Prometheus Alerts

Configured alerts:

| Alert | Purpose |
|---|---|
| HighErrorRate | Detect excessive 5xx responses |
| RestartLoop | Detect excessive pod restarts |

Location:

```text
charts/widget-api/templates/prometheusrule.yaml
```

---

# CI Pipeline

GitHub Actions validates:

- YAML formatting
- Helm rendering
- kubeconform schema validation
- Kyverno policy tests
- Trivy vulnerability scanning

Workflow file:

```text
.github/workflows/ci.yml
```

---

# Trivy Exception Handling

The provided upstream `podinfo` image contains HIGH and CRITICAL vulnerabilities identified by Trivy.

To demonstrate controlled exception handling, I implemented:

```text
.trivyignore
```

This allowed documented exception management while preserving visibility into upstream findings.

---

# Repository Structure

```text
.
├── .github/workflows/
├── charts/widget-api/
├── clusters/
├── dashboards/
├── policies/
├── screenshots/
├── scripts/
├── tests/kyverno/
├── README.md
└── TROUBLESHOOTING.md
```

---

# Bootstrap

## Requirements

- Docker Desktop
- WSL Ubuntu
- kubectl
- kind
- Helm
- Istioctl
- Kyverno CLI
- kubeconform
- Trivy

---

## Build Cluster

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

---

# Validation

## Check Platform

```bash
kubectl get pods -A
```

---

## Check widget-api

```bash
kubectl get pods -n widget-api
```

Expected:

```text
2/2 Running
```

The `2/2` confirms:
- application container
- Istio sidecar

---

## Validate Access Controls

```bash
./scripts/test-access.sh
```

Expected:

```text
frontend -> success
blocked -> RBAC: access denied
```

---

## Validate Manifests

```bash
./scripts/validate.sh
```

---

# Grafana Access

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```

Open:

```text
http://localhost:3000
```

Get password:

```bash
kubectl get secret kube-prometheus-stack-grafana \
  -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Username:

```text
admin
```

---

# Prometheus Access

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
```

Open:

```text
http://localhost:9090
```

