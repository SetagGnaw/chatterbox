# Engineering Notes

Fill this in as you build. Use evidence from commands, failures, and measurements
rather than retrospective generalities.

## Architecture decisions

### Why GitHub Actions for CI?

Decision:

Alternatives considered:

Tradeoff accepted:

### Why Argo CD for deployment?

Decision:

Alternatives considered:

Tradeoff accepted:

### Why one repository or separate repositories?

Decision:

Migration path:

### What is the immutable release identity?

Decision:

How source, workflow run, image digest, and GitOps commit are correlated:

### Why App-of-Apps, and how are cert-manager/external-secrets installed?

Decision: The Argo layer is an App-of-Apps. `gitops/argocd/root.yaml` is a single
root Application whose source is the directory `gitops/argocd/apps/`; each file
there is a child Application. cert-manager and external-secrets are installed by
child Applications that point `source.chart` + `source.repoURL` at the upstream
Helm repos (`charts.jetstack.io`, `charts.external-secrets.io`), so Argo CD
renders the official charts with its embedded Helm and reconciles the result. No
imperative `helm install` runs against the cluster.

Alternatives considered: extending `scripts/bootstrap.sh` with
`helm upgrade --install` (imperative, simpler, but the controllers would live
outside Argo's reconciliation and drift detection).

Ordering: child Applications carry `argocd.argoproj.io/sync-wave` annotations so
the controllers and their CRDs (wave -3) apply before the cluster-scoped custom
resources in `gitops/platform/` (wave -1) and the chatterbox app (wave 0). The
controller apps use `ServerSideApply=true` to avoid the client-side
`metadata.annotations too long` error on the large CRDs; the existing retry
backoff absorbs the transient window while cert-manager's webhook starts.

Wiring tradeoff: cert-manager uses a self-signed `ClusterIssuer`, which is fully
self-contained on kind and proves cert issuance end to end (an issued TLS cert).
external-secrets points its `ClusterSecretStore` at HashiCorp Vault running
in-cluster (installed by the `vault` child app in dev mode), so the whole secret
flow resolves on kind with no cloud dependency. Vault's Kubernetes auth method
validates the controller's ServiceAccount token (no static credentials are
stored): a Vault config Job (part of the `platform-config` app, alongside the
ClusterIssuer and ClusterSecretStore) enables the auth method, writes a read
policy and a role bound to the `external-secrets` ServiceAccount. The Job
provisions **plumbing only** — no secret value is ever written from a committed
manifest.

The secret value is treated exactly as a real secret: it is seeded **out of
band** and never stored in Git. `make seed-secret` (`scripts/seed-secret.sh`)
sources the value from the `GREETING` env var or a gitignored local file
(`.local/chatterbox-dev-secret.env`) and pipes it into Vault over stdin (so it
never lands in the pod's process arguments):

```
printf '%s' "$GREETING" | kubectl -n vault exec -i vault-0 -- \
  env VAULT_TOKEN=root vault kv put secret/chatterbox/dev greeting=-
```

Only after seeding does the `ExternalSecret` reach `SecretSynced`. The split is
the point: Git is the source of truth for *plumbing* (auth, policy, role); Vault
is the source of truth for *values*, and those values come from a secure local
source, not the repo.

Ordering: `vault` and the controllers install at wave -3; the `platform-config`
app applies at -1 and, within it, the Vault config Job runs first (its own
sync-wave) before the `ClusterSecretStore`, so the store validates against an
already-configured Vault; the chatterbox `ExternalSecret` consumes it at 0. Dev
mode is ephemeral
(in-memory, single unsealed node, root token `root`) and is a local-demo choice
only; a real deploy swaps it for standalone/HA Vault with a proper unseal path
and a real auth backend, without changing the chart wiring. The Ingress object
still only routes once an ingress controller is added to the cluster.

## Failure experiments

| Experiment | Prediction | Observed behavior | Detection | Recovery | Improvement |
|---|---|---|---|---|---|
| CI test failure |  |  |  |  |  |
| Registry push succeeds, promotion fails |  |  |  |  |  |
| Invalid Helm value reaches promotion PR |  |  |  |  |  |
| Argo CD unavailable during Git change |  |  |  |  |  |
| Cluster unavailable during reconciliation |  |  |  |  |  |
| Manual live-state drift |  |  |  |  |  |
| Bad image fails readiness |  |  |  |  |  |
| Rollback to prior digest |  |  |  |  |  |

## Measurements

| Signal | Baseline | Result | Why it matters |
|---|---:|---:|---|
| PR validation duration |  |  | Developer feedback time |
| Image build duration, cold/warm |  |  | CI capacity and caching |
| Commit-to-Argo-detected time |  |  | Reconciliation latency |
| Sync-to-ready time |  |  | Deployment lead time |
| Failed rollout detection time |  |  | Release safety |
| Rollback-to-ready time |  |  | Recovery objective |

## System-design summary

Problem:

Constraints:

Design:

Two deepest decisions:

Largest failure discovered:

Measured improvement:

What I would change for hundreds of services and teams:

