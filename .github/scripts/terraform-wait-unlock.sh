#!/usr/bin/env bash
# Wait for Terraform state lock to be released by polling with a lightweight plan.
# Usage: run from repo root (e.g. in CI after Terraform setup). Requires .env and terraform image.
set -euo pipefail

MAX_WAIT_MINUTES="${TF_LOCK_WAIT_MINUTES:-10}"
SLEEP="${TF_LOCK_WAIT_SLEEP:-30}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

[[ -f .env ]] || { echo ".env not found" >&2; exit 1; }
mkdir -p terraform/plan

start=$(date +%s)
max_sec=$((MAX_WAIT_MINUTES * 60))

while true; do
  elapsed=$(($(date +%s) - start))
  [[ $elapsed -lt $max_sec ]] || { echo "Timeout waiting for state unlock (${MAX_WAIT_MINUTES} min)." >&2; exit 1; }

  docker run --rm \
    --env-file .env \
    -e HOME=/workspace \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd)/terraform:/workspace" \
    -w /workspace \
    terraform plan -refresh=false -input=false -out=/workspace/plan/wait.plan 2>&1 | tee /tmp/tf-wait-out.txt
  code=${PIPESTATUS[0]}

  if [[ $code -eq 0 ]]; then
    echo "State unlocked."
    exit 0
  fi
  if grep -qEi "locked|already locked" /tmp/tf-wait-out.txt 2>/dev/null; then
    echo "State locked, waiting ${SLEEP}s... (${elapsed}s elapsed)"
    sleep "$SLEEP"
    continue
  fi
  echo "Plan failed for a reason other than lock." >&2
  exit 1
done
