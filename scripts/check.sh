#!/usr/bin/env bash

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

passed=0
failed=0
skipped=0

run_check() {
  local label=$1
  shift
  local output

  if output=$("$@" 2>&1); then
    printf '[PASS] %s\n' "$label"
    passed=$((passed + 1))
  else
    printf '[FAIL] %s\n' "$label"
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" | sed 's/^/       /'
    fi
    failed=$((failed + 1))
  fi
}

run_marker_check() {
  local label=$1
  local file=$2
  local pattern=$3

  run_check "$label" bash -c \
    "! grep -En '$pattern' '$file'"
}

run_check "Go files are formatted" bash -c \
  'test -z "$(gofmt -l ./cmd)"'
run_check "Go tests" go test ./...
run_check "Go vet" go vet ./...
run_check "Helm lint with dev values" \
  helm lint charts/chatterbox --values gitops/environments/dev/values.yaml
run_check "Helm template renders" bash -c \
  'helm template chatterbox charts/chatterbox --namespace chatterbox-dev --values gitops/environments/dev/values.yaml >/dev/null'

if command -v actionlint >/dev/null 2>&1; then
  run_check "GitHub workflow syntax" \
    actionlint .github/workflows/ci.yaml .github/workflows/release.yaml
else
  printf '[SKIP] GitHub workflow syntax (actionlint is not installed)\n'
  skipped=$((skipped + 1))
fi

if command -v yamllint >/dev/null 2>&1; then
  run_check "YAML style and syntax" \
    yamllint -d \
      '{extends: default, rules: {line-length: disable, document-start: disable, truthy: disable}}' \
      .github/workflows gitops charts/chatterbox/Chart.yaml charts/chatterbox/values.yaml
else
  printf '[SKIP] YAML style and syntax (yamllint is not installed)\n'
  skipped=$((skipped + 1))
fi

if docker info >/dev/null 2>&1; then
  run_check "Container image builds" \
    docker build --build-arg VERSION=check -t chatterbox:check .
else
  printf '[SKIP] Container image builds (Docker daemon is not running)\n'
  skipped=$((skipped + 1))
fi

run_marker_check "Milestone 1 CI workflow implemented" \
  .github/workflows/ci.yaml 'TODO|exit 1'
run_marker_check "Milestones 3-4 release workflow implemented" \
  .github/workflows/release.yaml 'TODO|exit 1'
run_check "Argo CD repository URL configured" bash -c \
  "! grep -Enr 'REPLACE_ME' gitops/argocd gitops/platform"
run_marker_check "Dev image repository configured" \
  gitops/environments/dev/values.yaml 'REPLACE_ME'

total=$((passed + failed))
printf '\n%d/%d checks passed; %d skipped\n' "$passed" "$total" "$skipped"

if ((failed > 0)); then
  exit 1
fi
