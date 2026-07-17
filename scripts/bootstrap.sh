#!/usr/bin/env bash

# Bootstrap the Milestone 5 local GitOps loop:
# kind cluster, Argo CD installed via Helm, chatterbox Application.
# Idempotent: safe to rerun after a partial failure.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

CLUSTER_NAME="${CLUSTER_NAME:-chatterbox}"
KUBE_CONTEXT="kind-${CLUSTER_NAME}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
# Optional chart pin, e.g. ARGOCD_CHART_VERSION=8.1.2; empty means latest.
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-}"
APPLICATION_MANIFEST="gitops/argocd/application.yaml"

info() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# preflight checks
for tool in docker kind helm kubectl; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed"
done
docker info >/dev/null 2>&1 || die "Docker daemon is not running"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  info "kind cluster '$CLUSTER_NAME' already exists"
else
  info "Creating kind cluster '$CLUSTER_NAME'"
  kind create cluster --name "$CLUSTER_NAME"
fi

info "Installing Argo CD via the argo-helm chart"
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo >/dev/null

version_args=()
if [[ -n "$ARGOCD_CHART_VERSION" ]]; then
  version_args=(--version "$ARGOCD_CHART_VERSION")
fi

helm upgrade --install argocd argo/argo-cd \
  --kube-context "$KUBE_CONTEXT" \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --wait \
  --timeout 10m \
  ${version_args[@]+"${version_args[@]}"}

info "Applying the chatterbox Application"
kubectl --context "$KUBE_CONTEXT" apply -f "$APPLICATION_MANIFEST"

info "Argo CD applications"
kubectl --context "$KUBE_CONTEXT" get applications -n "$ARGOCD_NAMESPACE"

cat <<EOF
  Bootstrap complete. The Application only becomes healthy once the repo
  is pushed (Milestone 2) and an image is published to GHCR (Milestone 3).

  Next steps:

    # Argo CD UI password (user: admin)
    kubectl --context ${KUBE_CONTEXT} -n ${ARGOCD_NAMESPACE} \\
      get secret argocd-initial-admin-secret \\
      -o jsonpath='{.data.password}' | base64 -d; echo

    # Argo CD UI at https://localhost:8080
    kubectl --context ${KUBE_CONTEXT} -n ${ARGOCD_NAMESPACE} \\
      port-forward svc/argocd-server 8080:443

    # Watch the app come up
    kubectl --context ${KUBE_CONTEXT} get all -n chatterbox-dev

  To tear everything down:

    kind delete cluster --name ${CLUSTER_NAME}
EOF
