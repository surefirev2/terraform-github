#!/usr/bin/env sh
# Synced from template — do not edit. Changes will be overwritten on the next sync.
# After plan has been run (plan-output.txt, plan-exit.txt), parse lock ID and lock Created time.
# If lock is stale (created >= STALE_SECONDS ago, or same lock cached for >= STALE_SECONDS),
# force-unlock and retry plan. Otherwise save current lock and exit 1.
# Usage: LOCK_CACHE_DIR=.terraform-lock-cache STALE_SECONDS=300 terraform-lock-handle.sh
# Expects: plan-output.txt, plan-exit.txt, LOCK_ID in env. Run from repo root.
# Uses: .github/scripts/terraform-lock-age.sh, make force-unlock LOCK_ID=..., make plan.

set -e

CACHE_DIR="${LOCK_CACHE_DIR:-.terraform-lock-cache}"
STALE_SECONDS="${STALE_SECONDS:-300}"

if [ ! -f plan-exit.txt ]; then
  echo "plan-exit.txt missing (plan step may not have written it); cannot handle lock."
  exit 1
fi
plan_exit="$(cat plan-exit.txt)"
if [ "$plan_exit" = "0" ]; then
  mkdir -p "$CACHE_DIR"
  echo "" > "$CACHE_DIR/lock_id"
  echo "0" > "$CACHE_DIR/lock_timestamp"
  exit 0
fi

if [ -z "$LOCK_ID" ]; then
  exit 1
fi

now=$(date +%s)
stale=0

# Stale if lock Created time in plan output is old enough.
if [ -r plan-output.txt ]; then
  lock_created_epoch="$(sh .github/scripts/terraform-lock-age.sh plan-output.txt 2>/dev/null)" || true
  if [ -n "$lock_created_epoch" ] && [ "$lock_created_epoch" -gt 0 ]; then
    lock_age=$((now - lock_created_epoch))
    if [ "$lock_age" -ge "$STALE_SECONDS" ]; then
      echo "Lock is stale (created ${lock_age}s ago, threshold ${STALE_SECONDS}s). Force-unlocking."
      stale=1
    fi
  fi
fi

# Stale if same lock was cached and cache is old enough.
if [ "$stale" -eq 0 ]; then
  cached_id=""
  cached_ts="0"
  [ -f "$CACHE_DIR/lock_id" ] && cached_id="$(cat "$CACHE_DIR/lock_id")"
  [ -f "$CACHE_DIR/lock_timestamp" ] && cached_ts="$(cat "$CACHE_DIR/lock_timestamp")"
  cache_age=$((now - cached_ts))
  if [ "$cached_id" = "$LOCK_ID" ] && [ "$cache_age" -ge "$STALE_SECONDS" ]; then
    echo "Lock unchanged for ${cache_age}s (threshold ${STALE_SECONDS}s). Force-unlocking."
    stale=1
  fi
fi

if [ "$stale" -eq 1 ]; then
  make force-unlock LOCK_ID="$LOCK_ID"
  rm -rf "$CACHE_DIR"
  make plan 2>&1 | tee plan-output.txt
  echo "${PIPESTATUS[0]}" > plan-exit.txt
  retry_exit="$(cat plan-exit.txt)"
  if [ "$retry_exit" = "0" ]; then
    mkdir -p "$CACHE_DIR"
    echo "" > "$CACHE_DIR/lock_id"
    echo "0" > "$CACHE_DIR/lock_timestamp"
  fi
  exit "$retry_exit"
fi

mkdir -p "$CACHE_DIR"
echo "$LOCK_ID" > "$CACHE_DIR/lock_id"
echo "$now" > "$CACHE_DIR/lock_timestamp"
exit 1
