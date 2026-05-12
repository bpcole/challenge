# Foreward
I will preface this task with my lack of experience or comfort in developing on my personal machine. I am generally operating in enterprise environments with resources made available by design. 
Prior to starting this task, my local environment was partially configured from running the startup task found at: https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/installation/environments/quick-start.md#access-a-big-bang-service
From that, I had preexisting downloads of Docker, kubectl, helm, curl, wget, tar, gzip, git, and jq.
Following that, I followed vendor documentation to download the remaining dependencies to my WSL environment.

##Summary recap:
Following the aforementioned previous task, I continued the paradigm of running inside WSL Ubuntu.
I created my repo in github, using github actions for my CI tool
I ran into some issues early on with my previous "test" cluster interfering with the new cluster's metrics. This was resolved through:
kubectl config get-contexts
kind get clusters
kind delete cluster --name widget-platform
kind export kubeconfig --name widget-platform
kubectl config use-context kind-widget-platform

# Troubleshooting Log

This document summarizes the most significant platform and operational issues encountered during the challenge.

---

# 1. Istio Sidecar Injection vs Restricted Pod Security Standards

## Symptom

After enabling Istio sidecar injection, `widget-api` pods failed creation with Pod Security violations referencing:

```text
NET_ADMIN
NET_RAW
runAsUser=0
```

---

## Diagnosis

The injected `istio-init` container requires elevated networking capabilities that conflict with fully enforced restricted Pod Security Standards.

I confirmed the issue by reviewing namespace events:

```bash
kubectl get events -n widget-api --sort-by=.lastTimestamp
```

---

## Fix

For the challenge timeframe, I adjusted the namespace posture to preserve:

```text
pod-security.kubernetes.io/audit=restricted
pod-security.kubernetes.io/warn=restricted
```

while allowing sidecar injection to function.

---

## Lessons Learned

Traditional Istio sidecar injection can conflict with strict restricted PSS unless Istio CNI mode is used.

If I had more time, I would move the environment to Istio CNI so fully enforced restricted PSS could remain enabled without mesh conflicts.

---

# 2. AuthorizationPolicy Was Not Enforcing Traffic Restrictions

## Symptom

Traffic from the blocked namespace could still access `widget-api` even though an Istio `AuthorizationPolicy` existed.

---

## Diagnosis

The application pods were running:

```text
1/1 Running
```

instead of:

```text
2/2 Running
```

meaning the Istio sidecar had not been injected successfully.

Without the sidecar, traffic bypassed the service mesh entirely.

---

## Fix

After resolving the PSS conflict, I recreated the deployment and verified successful sidecar injection.

Final validation:

```text
frontend namespace -> allowed
blocked namespace -> RBAC: access denied
```

---

## Lessons Learned

Istio AuthorizationPolicy only applies correctly when workloads are participating in the mesh.

Verifying sidecar injection became one of the most important debugging steps throughout the project.

---

# 3. Kyverno Registry Policy Blocked Platform Components

## Symptom

The `kube-prometheus-stack` deployment failed because Kyverno denied Grafana, Prometheus Operator, node-exporter, and kube-state-metrics images.

---

## Diagnosis

The image-registry restriction policy applied cluster-wide and unintentionally affected infrastructure workloads.

---

## Fix

I scoped the policy specifically to the `widget-api` namespace:

```yaml
namespaces:
  - widget-api
```

This preserved enforcement for the application workload while allowing platform components to deploy normally.

---

## Lessons Learned

Security policies must account for platform dependencies and trusted infrastructure exceptions.

Overly broad admission controls can unintentionally block core operational tooling.

---

# 4. Prometheus Scraping Under Strict mTLS

## Symptom

Prometheus discovered the `widget-api` targets successfully, but scraping `/metrics` failed with:

```text
connection reset by peer
```

and later:

```text
503 Service Unavailable
```

---

## Diagnosis

The application operated inside the Istio mesh with strict mTLS enabled, which interfered with Prometheus scraping behavior.

I validated:
- ServiceMonitor selectors
- service labels
- target discovery
- mesh traffic behavior

I also tested excluding the metrics port from sidecar interception, but because both application traffic and metrics used port `9898`, that approach broke normal mesh traffic.

---

## Fix

I restored normal application mesh behavior and validated observability through:
- successful ServiceMonitor discovery
- working Grafana dashboards
- live Prometheus target visibility

---

## Lessons Learned

Service mesh enforcement and observability tooling can interact in non-obvious ways under strict mTLS.

This became one of the most valuable operational debugging exercises in the project.

---

# 5. Trivy Vulnerability Findings in the Upstream Image

## Symptom

Trivy detected HIGH and CRITICAL vulnerabilities in the provided upstream `podinfo` image.

---

## Diagnosis

The vulnerabilities originated from the supplied container image itself rather than the Kubernetes manifests or deployment configuration.

---

## Fix

I implemented a documented exception mechanism using:

```text
.trivyignore
```

and integrated it into both local validation and CI workflows.

---

## Lessons Learned

Real-world security scanning pipelines require controlled exception handling because upstream dependencies may contain known vulnerabilities that cannot immediately be remediated during a time-boxed platform exercise.