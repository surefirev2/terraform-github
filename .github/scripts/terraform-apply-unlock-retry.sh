#!/usr/bin/env bash
# Synced from template — do not edit. Changes will be overwritten on the next sync.
# Run terraform apply; if it fails with state lock error, force-unlock and retry once.
# Handles stale locks from cancelled or crashed runs when no other apply is in progress.
# Usage: run from repo root after terraform init. Requires .env.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

[[ -f .env ]] || { echo ".env not found" >&2; exit 1; }

APPLY_OUT="${APPLY_OUTPUT_FILE:-/tmp/terraform-apply-out.txt}"

run_apply() {
  make apply 2>&1 | tee "$APPLY_OUT"
  return "${PIPESTATUS[0]}"
}

if run_apply; then
  exit 0
fi

# Check if failure was due to state lock (stale or held by another process).
if ! grep -qEi "already locked|error acquiring the state lock|state already locked" "$APPLY_OUT" 2>/dev/null; then
  echo "Apply failed for a reason other than state lock." >&2
  exit 1
fi

LOCK_ID="$("$REPO_ROOT/.github/scripts/terraform-lock-id.sh" "$APPLY_OUT" 2>/dev/null)" || true
if [[ -z "${LOCK_ID:-}" ]]; then
  echo "Apply failed with lock error but could not parse lock ID." >&2
  exit 1
fi

echo "Force-unlocking stale state (ID=$LOCK_ID) and retrying apply..."
make force-unlock LOCK_ID="$LOCK_ID"
run_apply
