#!/usr/bin/env bash
# OWNED BY template-template — do not edit. Changes will be overwritten on the next sync unless made in this repo.
# Source: https://github.com/surefirev2/template-template
#
# Upsert a sticky comment on a PR with template sync preview (target repos, file list(s), and diff(s) per repo).
# Env: GH_TOKEN, REPOS (space-separated), COUNT, FILES_LIST (union), optional FILES_LIST_TEMPLATE (files_to_sync_%s.txt),
#      optional DIFF_FILE_TEMPLATE (sync_diff_%s.txt) for per-repo diffs; or single DIFF_FILE for backward compat.
#      optional CHILD_PR_URLS_FILE: path to file with "repo URL" lines (from sync step) to list draft PR links.
# Usage: template-sync-pr-comment.sh <pr_number> [--repo OWNER/REPO]
set -euo pipefail
if [[ -n "${DEBUG:-}" ]]; then set -x; fi

PR_NUMBER=""
REPO="${GITHUB_REPOSITORY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    *)      PR_NUMBER="$1"; shift ;;
  esac
done

[[ -n "$PR_NUMBER" ]] || { echo "PR number required" >&2; exit 1; }
[[ -n "$REPO" ]] || { echo "GITHUB_REPOSITORY or --repo required" >&2; exit 1; }

REPOS="${REPOS:-none}"
COUNT="${COUNT:-0}"
FILES_LIST="${FILES_LIST:-files_to_sync.txt}"
FILES_LIST_TEMPLATE="${FILES_LIST_TEMPLATE:-}"
DIFF_FILE="${DIFF_FILE:-}"
DIFF_FILE_TEMPLATE="${DIFF_FILE_TEMPLATE:-}"
CHILD_PR_URLS_FILE="${CHILD_PR_URLS_FILE:-}"
# Org for repo links (e.g. from GITHUB_REPOSITORY=surefirev2/template-template)
ORG="${REPO%%/*}"
# GitHub issue comment body limit is 65536 characters; leave headroom for markdown
MAX_DIFF_CHARS=60000
MARKER="<!-- template-sync-preview -->"

append_diff_section() {
  local path="$1"
  local label="$2"
  [[ -z "$path" || ! -f "$path" ]] && return 0
  [[ -s "$path" ]] || return 0
  echo ""
  echo "<details><summary>${label}</summary>"
  echo ""
  echo '```diff'
  if [[ $(wc -c < "$path") -gt $MAX_DIFF_CHARS ]]; then
    head -c "$MAX_DIFF_CHARS" "$path"
    echo ""
    echo "... (truncated)"
  else
    cat "$path"
  fi
  echo '```'
  echo ""
  echo "</details>"
}

BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

{
  echo "## Template sync preview"
  echo ""
  echo "If this PR is merged, the next sync will affect:"
  echo ""
  echo "**Target repositories:**"
  if [[ "$REPOS" == "none" || -z "$REPOS" ]]; then
    echo " \`${REPOS}\`"
  elif [[ -n "$CHILD_PR_URLS_FILE" && -f "$CHILD_PR_URLS_FILE" && -s "$CHILD_PR_URLS_FILE" ]]; then
    while read -r repo_name pr_url; do
      [[ -n "$repo_name" && -n "$pr_url" ]] || continue
      echo "- [\`${repo_name}\`](${pr_url})"
    done < "$CHILD_PR_URLS_FILE"
  else
    for r in $REPOS; do
      [[ -z "$r" ]] && continue
      echo "- [\`${r}\`](https://github.com/${ORG}/${r})"
    done
  fi
  echo ""
  echo "**Files to sync:** $COUNT"
  # Single file list (union) when no per-repo template
  if [[ -z "$FILES_LIST_TEMPLATE" && -f "$FILES_LIST" && -s "$FILES_LIST" ]]; then
    echo ""
    echo "<details><summary>File list</summary>"
    echo ""
    echo '```'
    cat "$FILES_LIST"
    echo '```'
    echo ""
    echo "</details>"
  fi
  # Per-repo file lists and diffs when templates are set
  if [[ -n "$FILES_LIST_TEMPLATE" || -n "$DIFF_FILE_TEMPLATE" ]]; then
    for r in $REPOS; do
      [[ -z "$r" ]] || [[ "$r" == "none" ]] && continue
      if [[ -n "$FILES_LIST_TEMPLATE" ]]; then
        fl=$(printf "$FILES_LIST_TEMPLATE" "$r")
        if [[ -f "$fl" && -s "$fl" ]]; then
          echo ""
          echo "<details><summary>File list for \`$r\`</summary>"
          echo ""
          echo '```'
          cat "$fl"
          echo '```'
          echo ""
          echo "</details>"
        fi
      fi
      if [[ -n "$DIFF_FILE_TEMPLATE" ]]; then
        df=$(printf "$DIFF_FILE_TEMPLATE" "$r")
        append_diff_section "$df" "Diff of synced files for \`$r\` (base → PR head)"
      fi
    done
  else
    # Single diff (backward compat)
    if [[ -n "$DIFF_FILE" && -f "$DIFF_FILE" && -s "$DIFF_FILE" ]]; then
      append_diff_section "$DIFF_FILE" "Diff of synced files (base → PR head)"
    fi
  fi
  echo ""
  echo "*Draft PRs are opened in child repos on each update to this PR; they are marked ready for review when this PR is merged to \`main\`.*"
  echo ""
  echo "$MARKER"
} > "$BODY_FILE"

# Don't fail the script if list-comments fails (e.g. API error); with pipefail, a failing gh in the pipeline would exit
COMMENT_ID=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.user.login == \"github-actions[bot]\" and (.body | contains(\"$MARKER\"))) | .id" 2>/dev/null | head -1) || true

if [[ -n "$COMMENT_ID" ]]; then
  jq -n --rawfile b "$BODY_FILE" '{body: $b}' | gh api -X PATCH "repos/${REPO}/issues/comments/${COMMENT_ID}" --input -
  echo "Updated existing template sync preview comment."
else
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body-file "$BODY_FILE"
  echo "Posted new template sync preview comment."
fi
