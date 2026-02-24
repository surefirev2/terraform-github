#!/usr/bin/env bash
# OWNED BY template-template — do not edit. Changes will be overwritten on the next sync unless made in this repo.
# Source: https://github.com/surefirev2/template-template
#
# For each dependent repo: clone, copy included files, push branch, create or update PR.
# Env: ORG, GH_TOKEN (not required if DRY_RUN=1), BRANCH, REPOS_LIST, FILES_LIST or FILES_LIST_TEMPLATE (e.g. files_to_sync_%s.txt).
#       GITHUB_REPOSITORY (repo running the workflow) for commit/PR attribution.
#       PARENT_PR_NUMBER: optional; when set (e.g. when syncing from a parent PR), appended to BRANCH so one downstream PR per parent PR.
#       PARENT_PR_URL: optional; when set, linked in child PR body (e.g. https://github.com/org/repo/pull/123).
#       CHILD_PR_URLS_FILE: optional path to append "repo PR_URL" lines for each child PR (used by PR comment).
# Options: --dry-run (no clone/push/pr), --draft (create PR as draft).
# Usage: template-sync-push-pr.sh [--dry-run] [--draft]
set -euo pipefail
if [[ -n "${DEBUG:-}" ]]; then set -x; fi

DRY_RUN="${DRY_RUN:-}"
DRAFT_PR="${DRAFT_PR:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --draft)   DRAFT_PR=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

ORG="${ORG:?ORG required}"
# GH_TOKEN required only when not dry-run
if [[ -z "${DRY_RUN}" ]]; then
  GH_TOKEN="${GH_TOKEN:?GH_TOKEN required}"
fi
# Unique per source repo so multiple template parents don't share one branch in a child
if [[ -n "${BRANCH:-}" ]]; then
  :
elif [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  BRANCH="chore/template-sync-${GITHUB_REPOSITORY//\//-}"
else
  BRANCH="chore/template-sync"
fi
# When syncing from a parent PR, include its number so each parent PR gets its own downstream branch/PR
[[ -n "${PARENT_PR_NUMBER:-}" ]] && BRANCH="${BRANCH}-${PARENT_PR_NUMBER}"
REPOS_LIST="${REPOS_LIST:-}"
FILES_LIST="${FILES_LIST:-files_to_sync.txt}"
FILES_LIST_TEMPLATE="${FILES_LIST_TEMPLATE:-}"
SOURCE_REPO="${GITHUB_REPOSITORY:-$ORG/template-template}"
PARENT_PR_URL="${PARENT_PR_URL:-}"
CHILD_PR_URLS_FILE="${CHILD_PR_URLS_FILE:-}"
# Resolve to absolute path so appends work when we cd into dest_repo (otherwise file is written inside dest_repo and removed)
[[ -n "$CHILD_PR_URLS_FILE" && "$CHILD_PR_URLS_FILE" != /* ]] && CHILD_PR_URLS_FILE="$(pwd)/$CHILD_PR_URLS_FILE"

[[ -n "$REPOS_LIST" ]] || { echo "No dependent repos to sync."; exit 0; }
[[ -z "$CHILD_PR_URLS_FILE" ]] || : > "$CHILD_PR_URLS_FILE"

for repo in $REPOS_LIST; do
  [[ -n "$repo" ]] || continue
  [[ "$repo" != "template-template" ]] || continue

  # Per-repo file list when FILES_LIST_TEMPLATE is set (e.g. files_to_sync_%s.txt)
  if [[ -n "$FILES_LIST_TEMPLATE" ]]; then
    FILES_LIST=$(printf "$FILES_LIST_TEMPLATE" "$repo")
  fi
  [[ -f "$FILES_LIST" ]] || { echo "Files list not found: $FILES_LIST" >&2; exit 1; }
  # Absolute path so we can read the list after cd into dest_repo
  FILES_LIST_ABS="$FILES_LIST"
  [[ "$FILES_LIST_ABS" == /* ]] || FILES_LIST_ABS="$(pwd)/$FILES_LIST_ABS"

  if [[ -n "${DRY_RUN}" ]]; then
    echo "--- [dry-run] Would sync to $ORG/$repo ---"
    echo "  Files:"
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      echo "    - $f"
    done < "$FILES_LIST"
    echo "  (no clone, push, or PR)"
    continue
  fi

  echo "--- Syncing to $ORG/$repo ---"
  rm -rf dest_repo
  git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${ORG}/${repo}.git" dest_repo
  cd dest_repo
  git fetch origin "${BRANCH}" 2>/dev/null && git checkout "${BRANCH}" || git checkout -b "${BRANCH}"
  cd ..

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    mkdir -p "dest_repo/$(dirname "$f")"
    cp "$f" "dest_repo/$f" 2>/dev/null || true
  done < "$FILES_LIST"

  cd dest_repo
  git add -A
  # Apply file modes (e.g. executable bit) from template so diff detects permission-only changes
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    mode=$(git -C .. ls-files -s -- "$f" 2>/dev/null | awk '{print $1}')
    if [[ "$mode" == 100755 ]]; then
      git update-index --chmod=+x "$f"
    elif [[ "$mode" == 100644 ]]; then
      git update-index --chmod=-x "$f"
    fi
  done < "$FILES_LIST_ABS"
  if git diff --staged --quiet; then
    echo "  No changes for $repo"
    # Still update PR state (e.g. mark draft as ready when syncing after merge)
    PR=$(gh pr list --repo "${ORG}/${repo}" --head "${BRANCH}" --json number -q '.[0].number' 2>/dev/null || true)
    if [[ -n "$PR" && "$PR" != "null" ]]; then
      if [[ -z "${DRAFT_PR}" ]]; then
        is_draft=$(gh pr view "$PR" --repo "${ORG}/${repo}" --json isDraft -q '.isDraft' 2>/dev/null || true)
        if [[ "$is_draft" == "true" ]]; then
          gh pr ready "$PR" --repo "${ORG}/${repo}"
          echo "  PR #$PR marked ready for review"
        fi
      fi
      # Record child PR URL so the parent PR comment can link to it
      if [[ -n "$CHILD_PR_URLS_FILE" ]]; then
        pr_url=$(gh pr view "$PR" --repo "${ORG}/${repo}" --json url -q '.url' 2>/dev/null || true)
        [[ -n "$pr_url" ]] && echo "$repo $pr_url" >> "$CHILD_PR_URLS_FILE"
      fi
    fi
    cd ..
    rm -rf dest_repo
    continue
  fi

  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git commit -m "chore(template): sync from $SOURCE_REPO"
  git push origin "${BRANCH}" --force

  DEFAULT_BASE=$(gh repo view "${ORG}/${repo}" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
  PR_BODY_FILE=$(mktemp)
  {
    echo "Automated sync from $SOURCE_REPO."
    [[ -n "${PARENT_PR_URL:-}" ]] && echo " [Parent PR](${PARENT_PR_URL})."
    echo ""
    if [[ -n "${PARENT_PR_NUMBER:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
      PARENT_PR_BODY=$(gh pr view "$PARENT_PR_NUMBER" --repo "$GITHUB_REPOSITORY" --json body -q '.body' 2>/dev/null || true)
      if [[ -n "${PARENT_PR_BODY}" ]]; then
        echo "**Parent PR description:**"
        echo ""
        printf '%s' "$PARENT_PR_BODY" | sed 's/^/> /'
        echo ""
        echo ""
      fi
    fi
    echo "Merge when checks pass."
  } > "$PR_BODY_FILE"
  PR=$(gh pr list --repo "${ORG}/${repo}" --head "${BRANCH}" --json number -q '.[0].number' 2>/dev/null || true)
  if [[ -z "$PR" || "$PR" = "null" ]]; then
    if [[ -n "${DRAFT_PR}" ]]; then
      gh pr create --repo "${ORG}/${repo}" --base "${DEFAULT_BASE}" --head "${BRANCH}" \
        --title "chore(template): sync from $SOURCE_REPO" \
        --body-file "$PR_BODY_FILE" \
        --draft
    else
      gh pr create --repo "${ORG}/${repo}" --base "${DEFAULT_BASE}" --head "${BRANCH}" \
        --title "chore(template): sync from $SOURCE_REPO" \
        --body-file "$PR_BODY_FILE"
    fi
    rm -f "$PR_BODY_FILE"
    PR=$(gh pr list --repo "${ORG}/${repo}" --head "${BRANCH}" --json number -q '.[0].number' 2>/dev/null || true)
  else
    rm -f "$PR_BODY_FILE"
    if [[ -z "${DRAFT_PR}" ]]; then
      is_draft=$(gh pr view "$PR" --repo "${ORG}/${repo}" --json isDraft -q '.isDraft' 2>/dev/null || true)
      if [[ "$is_draft" == "true" ]]; then
        gh pr ready "$PR" --repo "${ORG}/${repo}"
        echo "  PR #$PR marked ready for review"
      else
        echo "  PR #$PR already open"
      fi
    else
      is_draft=$(gh pr view "$PR" --repo "${ORG}/${repo}" --json isDraft -q '.isDraft' 2>/dev/null || true)
      if [[ "$is_draft" != "true" ]]; then
        echo '{"draft":true}' | gh api -X PATCH "repos/${ORG}/${repo}/pulls/${PR}" --input -
        echo "  PR #$PR marked as draft"
      else
        echo "  PR #$PR already open (draft)"
      fi
    fi
  fi
  if [[ -n "$CHILD_PR_URLS_FILE" && -n "$PR" && "$PR" != "null" ]]; then
    pr_url=$(gh pr view "$PR" --repo "${ORG}/${repo}" --json url -q '.url' 2>/dev/null || true)
    [[ -n "$pr_url" ]] && echo "$repo $pr_url" >> "$CHILD_PR_URLS_FILE"
  fi

  cd ..
  rm -rf dest_repo
done

echo "Done."
