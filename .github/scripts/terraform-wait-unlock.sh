#!/usr/bin/env bash
# Wait for Terraform state lock to be released by polling with a lightweight plan.
# After MAX_WAIT_MINUTES, force-unlocks the state and exits 0 so the workflow can proceed.
# Usage: run from repo root (e.g. in CI after Terraform setup). Requires .env and terraform image.
set -euo pipefail

MAX_WAIT_MINUTES="${TF_LOCK_WAIT_MINUTES:-5}"
SLEEP="${TF_LOCK_WAIT_SLEEP:-30}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

[[ -f .env ]] || { echo ".env not found" >&2; exit 1; }
mkdir -p terraform/plan

start=$(date +%s)
max_sec=$((MAX_WAIT_MINUTES * 60))

while true; do
  elapsed=$(($(date +%s) - start))
  if [[ $elapsed -ge $max_sec ]]; then
    echo "Timeout waiting for state unlock (${MAX_WAIT_MINUTES} min). Force-unlocking..." >&2
    LOCK_ID="$("$REPO_ROOT/.github/scripts/terraform-lock-id.sh" /tmp/tf-wait-out.txt 2>/dev/null)" || true
    if [[ -n "${LOCK_ID:-}" ]]; then
      echo "Force-unlocking state (ID=$LOCK_ID)"
      docker run --rm \
        --env-file .env \
        -e HOME=/workspace \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd)/terraform:/workspace" \
        -w /workspace \
        terraform force-unlock -force "$LOCK_ID"
      echo "State force-unlocked. Proceeding."
      exit 0
    fi
    echo "Timeout but could not parse lock ID from plan output." >&2
    exit 1
  fi

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
