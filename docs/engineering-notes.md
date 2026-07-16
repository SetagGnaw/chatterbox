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

