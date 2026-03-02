#!/usr/bin/env bash
# OWNED BY template-template — do not edit. Changes will be overwritten on the next sync unless made in this repo.
# Source: https://github.com/surefirev2/template-template
#
# Build list of template files to sync.
# Paths in include_paths / repo_include_paths may end with "/*" to mean all tracked files under that directory (e.g. .github/scripts/*).
# With --repos: build per-repo files_to_sync_<repo>.txt = global include_paths + repo_include_paths[repo] (merged)
#   and union files_to_sync.txt for preview/diff.
# Without --repos: single list from --include-file or --exclusions-file.
# Writes count to GITHUB_OUTPUT.
# Usage: template-sync-build-file-list.sh [--repos "r1 r2"] (--include-file PATH | --exclusions-file PATH) [--include-dir DIR] [--output-dir DIR] [--output FILE]
set -euo pipefail
if [[ -n "${DEBUG:-}" ]]; then set -x; fi

REPOS_LIST=""
INCLUDE_FILE=""
EXCLUSIONS_FILE=""
INCLUDE_DIR="."
OUTPUT_DIR="."
OUTPUT_FILE="files_to_sync.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos)          REPOS_LIST="$2"; shift 2 ;;
    --include-file)   INCLUDE_FILE="$2"; shift 2 ;;
    --exclusions-file) EXCLUSIONS_FILE="$2"; shift 2 ;;
    --include-dir)    INCLUDE_DIR="$2"; shift 2 ;;
    --output-dir)     OUTPUT_DIR="$2"; shift 2 ;;
    --output)         OUTPUT_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$INCLUDE_FILE" ]] || [[ -n "$EXCLUSIONS_FILE" ]] || { echo "Need --include-file or --exclusions-file" >&2; exit 1; }

# Expand a path that may contain a trailing "/*" to all tracked files under that prefix.
expand_path() {
  local path="$1"
  if [[ "$path" == *'*'* ]]; then
    # e.g. .github/scripts/* -> prefix .github/scripts/, match all tracked files under it
    local prefix="${path%%/\*}"
    if [[ -n "$prefix" ]]; then
      local esc="${prefix//./\\.}"
      grep -E "^${esc}/" all_files.txt 2>/dev/null || true
    fi
  else
    grep -Fx "$path" all_files.txt 2>/dev/null || true
  fi
}

build_one_list() {
  local src_file="$1"
  local out_file="$2"
  if [[ -n "$src_file" && -s "$src_file" ]]; then
    git ls-files > all_files.txt
    > "$out_file"
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      expand_path "$path" >> "$out_file"
    done < "$src_file"
    sort -u "$out_file" -o "$out_file"
  else
    # Blacklist fallback
    git ls-files > all_files.txt
    if [[ -n "$EXCLUSIONS_FILE" && -s "$EXCLUSIONS_FILE" ]]; then
      while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        sed -i "\|^${path}$|d" all_files.txt 2>/dev/null || true
        sed -i "\|^${path}/|d" all_files.txt 2>/dev/null || true
      done < "$EXCLUSIONS_FILE"
    fi
    sort -u all_files.txt -o "$out_file"
  fi
}

if [[ -n "$REPOS_LIST" ]]; then
  # Per-repo mode: each repo gets global include_paths + its repo_include_paths (if any), merged
  for repo in $REPOS_LIST; do
    [[ -z "$repo" ]] && continue
    merged=$(mktemp)
    trap "rm -f '$merged'" RETURN
    [[ -s "$INCLUDE_FILE" ]] && cat "$INCLUDE_FILE" >> "$merged"
    repo_include="$INCLUDE_DIR/include_paths_${repo}.txt"
    [[ -s "$repo_include" ]] && cat "$repo_include" >> "$merged"
    sort -u "$merged" -o "$merged"
    build_one_list "$merged" "$OUTPUT_DIR/files_to_sync_${repo}.txt"
    rm -f "$merged"
  done
  # Union for preview and diff
  cat "$OUTPUT_DIR"/files_to_sync_*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/$OUTPUT_FILE" || true
  [[ -s "$OUTPUT_DIR/$OUTPUT_FILE" ]] || : > "$OUTPUT_DIR/$OUTPUT_FILE"
  COUNT=$(wc -l < "$OUTPUT_DIR/$OUTPUT_FILE")
else
  # Single-list mode (backward compatible)
  build_one_list "$INCLUDE_FILE" "$OUTPUT_DIR/$OUTPUT_FILE"
  COUNT=$(wc -l < "$OUTPUT_DIR/$OUTPUT_FILE")
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "count=$COUNT" >> "$GITHUB_OUTPUT"
fi

echo "Files to sync: $COUNT"
