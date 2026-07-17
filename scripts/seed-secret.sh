#!/usr/bin/env bash

# Seed the chatterbox dev secret into Vault OUT OF BAND.
#
# The value is treated as a real secret: it never lives in Git. It is sourced
# from the GREETING env var, or from a gitignored local file
# (.local/chatterbox-dev-secret.env by default) containing:
#
#   GREETING=your-value
#
# Run this after the stack is up (the vault pod is Ready). external-secrets
# picks up the value on its next refresh and the ExternalSecret reaches
# SecretSynced.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

CLUSTER_NAME="${CLUSTER_NAME:-chatterbox}"
KUBE_CONTEXT="kind-${CLUSTER_NAME}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
SECRET_FILE="${SECRET_FILE:-.local/chatterbox-dev-secret.env}"

info() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Env var wins; otherwise read the gitignored local file.
if [[ -z "${GREETING:-}" && -f "$SECRET_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$SECRET_FILE"
fi

if [[ -z "${GREETING:-}" ]]; then
  die "no secret value found. Set GREETING=... or create $SECRET_FILE (gitignored) with 'GREETING=your-value'"
fi

info "Waiting for $VAULT_POD in namespace $VAULT_NAMESPACE"
kubectl --context "$KUBE_CONTEXT" -n "$VAULT_NAMESPACE" \
  wait --for=condition=Ready "pod/$VAULT_POD" --timeout=120s

# Pipe the value over stdin (greeting=-) so it never appears in the pod's
# process arguments.
info "Writing secret/chatterbox/dev to Vault"
printf '%s' "$GREETING" \
  | kubectl --context "$KUBE_CONTEXT" -n "$VAULT_NAMESPACE" \
      exec -i "$VAULT_POD" -- \
      env VAULT_TOKEN=root VAULT_ADDR=http://127.0.0.1:8200 \
      vault kv put secret/chatterbox/dev greeting=-

info "Seeded. external-secrets will sync on its next refresh interval."
