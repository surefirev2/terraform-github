#!/usr/bin/env bash
# Wait for Terraform state lock to be released by polling with a lightweight plan.
# After MAX_WAIT_MINUTES, force-unlocks the state and exits 0 so the workflow can proceed.
# Usage: run from repo root (e.g. in CI after Terraform setup). Requires .env and terraform image.
# Debug: set TF_LOCK_DEBUG=1 to enable set -x and extra logging.
set -euo pipefail

# Enable debug when TF_LOCK_DEBUG is set (e.g. 1, true, yes)
if [[ -n "${TF_LOCK_DEBUG:-}" ]]; then
  set -x
fi

MAX_WAIT_MINUTES="${TF_LOCK_WAIT_MINUTES:-5}"
SLEEP="${TF_LOCK_WAIT_SLEEP:-30}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

[[ -f .env ]] || { echo ".env not found" >&2; exit 1; }
mkdir -p terraform/plan

start=$(date +%s)
max_sec=$((MAX_WAIT_MINUTES * 60))

if [[ -n "${TF_LOCK_DEBUG:-}" ]]; then
  echo "[tf-wait-unlock] MAX_WAIT_MINUTES=$MAX_WAIT_MINUTES SLEEP=$SLEEP max_sec=$max_sec"
fi

# Match lock-related errors: "already locked", "state lock", "acquiring.*lock", "locked"
LOCK_PATTERN="already locked|state lock|acquiring.*lock|Error acquiring the state lock"
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
    [[ -n "${TF_LOCK_DEBUG:-}" ]] && tail -100 /tmp/tf-wait-out.txt >&2
    exit 1
  fi

  # Pipeline must not trigger set -e: we need to inspect output and wait or force-unlock.
  # With pipefail, a failing terraform plan would exit the script before we could check for lock.
  set +o pipefail
  docker run --rm \
    --env-file .env \
    -e HOME=/workspace \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd)/terraform:/workspace" \
    -w /workspace \
    terraform plan -refresh=false -input=false -out=/workspace/plan/wait.plan 2>&1 | tee /tmp/tf-wait-out.txt
  code=${PIPESTATUS[0]}
  set -o pipefail

  if [[ -n "${TF_LOCK_DEBUG:-}" ]]; then
    echo "[tf-wait-unlock] plan exit code=$code elapsed=${elapsed}s"
  fi

  if [[ $code -eq 0 ]]; then
    echo "State unlocked."
    exit 0
  fi
  if grep -qEi "$LOCK_PATTERN" /tmp/tf-wait-out.txt 2>/dev/null; then
    echo "State locked, waiting ${SLEEP}s... (${elapsed}s elapsed)"
    sleep "$SLEEP"
    continue
  fi
  echo "Plan failed for a reason other than lock." >&2
  if [[ -n "${TF_LOCK_DEBUG:-}" ]]; then
    echo "[tf-wait-unlock] lock pattern did not match. Last 80 lines of plan output:" >&2
    tail -80 /tmp/tf-wait-out.txt >&2
  fi
  exit 1
done
