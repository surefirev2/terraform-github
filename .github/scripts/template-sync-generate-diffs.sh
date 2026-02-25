#!/usr/bin/env bash
# OWNED BY template-template — do not edit. Changes will be overwritten on the next sync unless made in this repo.
# Source: https://github.com/surefirev2/template-template
#
# Generate per-repo diff files (sync_diff_<repo>.txt) for PR preview. Requires fetch-depth >= 2.
# Env: REPOS (space-separated). Uses HEAD^1 = base, HEAD^2 = PR head (merge commit).
# Usage: template-sync-generate-diffs.sh [--base REF] [--head REF]
set -euo pipefail
if [[ -n "${DEBUG:-}" ]]; then set -x; fi

BASE_REF="HEAD^1"
HEAD_REF="HEAD^2"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE_REF="$2"; shift 2 ;;
    --head) HEAD_REF="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

REPOS="${REPOS:-}"
[[ -n "$REPOS" ]] || { echo "REPOS required" >&2; exit 1; }

for r in $REPOS; do
  [[ -z "$r" ]] && continue
  list="files_to_sync_${r}.txt"
  [[ -s "$list" ]] || continue
  FILES=$(tr '\n' ' ' < "$list")
  git diff "$BASE_REF" "$HEAD_REF" -- $FILES > "sync_diff_${r}.txt" 2>/dev/null || echo -n '' > "sync_diff_${r}.txt"
  echo "Diff lines for $r: $(wc -l < "sync_diff_${r}.txt")"
done
