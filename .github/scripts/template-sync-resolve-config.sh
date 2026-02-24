#!/usr/bin/env bash
# OWNED BY template-template — do not edit. Changes will be overwritten on the next sync unless made in this repo.
# Source: https://github.com/surefirev2/template-template
#
# Resolve template-sync config: repo list (literal + glob), include_paths (allowlist), exclude_paths (blacklist).
# Writes GITHUB_OUTPUT (repos_list, exclusions), include_paths.txt and exclusions.txt in output dir.
# Usage: template-sync-resolve-config.sh [--config PATH] [--org ORG] [--out-dir DIR]
set -euo pipefail
if [[ -n "${DEBUG:-}" ]]; then set -x; fi

CONFIG=".github/template-sync.yml"
ORG="${GITHUB_REPOSITORY_OWNER:-}"
OUT_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)  CONFIG="$2"; shift 2 ;;
    --org)     ORG="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$ORG" ]] || { echo "ORG required (--org or GITHUB_REPOSITORY_OWNER)" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "Config not found: $CONFIG" >&2; exit 1; }

# Parse only the repositories section (stop at next top-level key like exclude_paths:)
REPOS_RAW=$(awk '/^repositories:/{flag=1;next} flag && /^[a-zA-Z_][a-zA-Z0-9_-]*:/{exit} flag' "$CONFIG" 2>/dev/null | grep -E '^\s*-\s*' | sed -E 's/^\s*-\s*"?([^"]+)"?.*/\1/' | tr '\n' ' ' || true)
REPOS=""
for entry in $REPOS_RAW; do
  [[ -z "$entry" ]] && continue
  if echo "$entry" | grep -q '\*'; then
    re=$(echo "$entry" | sed 's/\*/.*/g')
    for name in $(gh repo list "$ORG" --limit 200 --json name -q '.[].name' 2>/dev/null || true); do
      echo "$name" | grep -qE "^${re}$" && REPOS="${REPOS} ${name}"
    done
  else
    REPOS="${REPOS} ${entry}"
  fi
done
REPOS=$(echo "$REPOS" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

# Parse include_paths (default allowlist for all repos)
INCLUDES=$(awk '/^include_paths:/{flag=1;next} flag && /^[a-zA-Z_][a-zA-Z0-9_-]*:/{exit} flag' "$CONFIG" 2>/dev/null | grep -E '^\s*-\s*' | sed -E 's/^\s*-\s*"?([^"]+)"?.*/\1/' | grep -v '^\s*$' || true)
# Parse repo_include_paths (per-repo overrides: reponame -> list of paths)
awk '/^repo_include_paths:/{in_sec=1;next} in_sec && /^[a-zA-Z_][a-zA-Z0-9_-]*:/{in_sec=0} in_sec && /^  [a-zA-Z0-9_.-]+:/{gsub(/^  |:$/,"");repo=$0;next} in_sec && /^    - /{gsub(/^    - /,"");print repo, $0}' "$CONFIG" 2>/dev/null | while read -r repo path; do
  [[ -z "$repo" || -z "$path" ]] && continue
  echo "$path" >> "$OUT_DIR/include_paths_${repo}.txt"
done
for f in "$OUT_DIR"/include_paths_*.txt; do
  [[ -f "$f" ]] && sort -u "$f" -o "$f"
done
# Parse exclude_paths (blacklist; used when include_paths is empty)
EXCLUSIONS=$(awk '/^exclude_paths:/{flag=1;next} flag && /^[a-zA-Z_][a-zA-Z0-9_-]*:/{exit} flag' "$CONFIG" 2>/dev/null | grep -E '^\s*-\s*' | sed -E 's/^\s*-\s*"?([^"]+)"?.*/\1/' | grep -v '^\s*$' || true)
mkdir -p "$OUT_DIR"
echo "$INCLUDES" > "$OUT_DIR/include_paths.txt"
echo "$EXCLUSIONS" > "$OUT_DIR/exclusions.txt"

# GitHub Actions: write outputs
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "repos_list=$REPOS" >> "$GITHUB_OUTPUT"
  echo "exclusions<<EOF" >> "$GITHUB_OUTPUT"
  echo "$EXCLUSIONS" >> "$GITHUB_OUTPUT"
  echo "EOF" >> "$GITHUB_OUTPUT"
fi

echo "Resolved repos: ${REPOS:-none}"
