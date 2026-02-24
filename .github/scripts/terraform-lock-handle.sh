#!/usr/bin/env sh
# After plan has been run (plan-output.txt, plan-exit.txt), parse lock ID,
# compare with cached lock (if any), and either: save current lock and exit 1,
# or force-unlock and retry plan, or clear cache and exit 0.
# Usage: LOCK_CACHE_DIR=.terraform-lock-cache STALE_SECONDS=3600 terraform-lock-handle.sh
# Expects: plan-output.txt, plan-exit.txt, and LOCK_ID in env (from terraform-lock-id.sh).
# Uses: make force-unlock LOCK_ID=..., make plan (for retry).

set -e

CACHE_DIR="${LOCK_CACHE_DIR:-.terraform-lock-cache}"
STALE_SECONDS="${STALE_SECONDS:-3600}"

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
cached_id=""
cached_ts="0"
[ -f "$CACHE_DIR/lock_id" ] && cached_id="$(cat "$CACHE_DIR/lock_id")"
[ -f "$CACHE_DIR/lock_timestamp" ] && cached_ts="$(cat "$CACHE_DIR/lock_timestamp")"
age=$((now - cached_ts))

if [ "$cached_id" = "$LOCK_ID" ] && [ "$age" -ge "$STALE_SECONDS" ]; then
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
