#!/usr/bin/env bash
# OWNED BY template-template — do not edit. Changes will be overwritten on the next sync unless made in this repo.
# Source: https://github.com/surefirev2/template-template
#
# Append template sync preview to GITHUB_STEP_SUMMARY (GitHub Actions job summary).
# Env: REPOS (target repos), COUNT (file count), FILES_LIST (path to union file list, default files_to_sync.txt).
# Usage: template-sync-write-step-summary.sh
set -euo pipefail
if [[ -n "${DEBUG:-}" ]]; then set -x; fi

REPOS="${REPOS:-none}"
COUNT="${COUNT:-0}"
FILES_LIST="${FILES_LIST:-files_to_sync.txt}"
OUT="${GITHUB_STEP_SUMMARY:-/dev/null}"

{
  echo "## Template sync preview"
  echo ""
  echo "If this PR is merged, the next sync will affect:"
  echo ""
  echo "**Target repositories:** \`${REPOS}\`"
  echo ""
  echo "**Files to sync:** $COUNT"
  if [[ -f "$FILES_LIST" && -s "$FILES_LIST" ]]; then
    echo ""
    echo "<details><summary>File list</summary>"
    echo ""
    echo '```'
    cat "$FILES_LIST"
    echo '```'
    echo ""
    echo "</details>"
  fi
  echo ""
  echo "*Actual sync runs only on push to \`main\`.*"
} >> "$OUT"
