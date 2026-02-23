#!/usr/bin/env bash
# OWNED BY template-template — do not edit. Changes will be overwritten on the next sync unless made in this repo.
# Source: https://github.com/surefirev2/template-template
#
# GHA wrapper: choose include vs exclusions and per-repo vs single, then call template-sync-build-file-list.sh.
# Env: REPOS (space-separated, from config), cwd must have include_paths.txt and/or exclusions.txt.
# Usage: template-sync-ga-build-file-list.sh
set -euo pipefail
if [[ -n "${DEBUG:-}" ]]; then set -x; fi

REPOS="${REPOS:-}"
INCLUDE_FILE="include_paths.txt"
EXCLUSIONS_FILE="exclusions.txt"
INCLUDE_DIR="."
OUTPUT_DIR="."

if [[ -n "$REPOS" ]]; then
  if [[ -s "$INCLUDE_FILE" ]]; then
    exec bash "$(dirname "$0")/template-sync-build-file-list.sh" --repos "$REPOS" --include-file "$INCLUDE_FILE" --include-dir "$INCLUDE_DIR" --output-dir "$OUTPUT_DIR"
  else
    exec bash "$(dirname "$0")/template-sync-build-file-list.sh" --repos "$REPOS" --exclusions-file "$EXCLUSIONS_FILE" --include-dir "$INCLUDE_DIR" --output-dir "$OUTPUT_DIR"
  fi
else
  if [[ -s "$INCLUDE_FILE" ]]; then
    exec bash "$(dirname "$0")/template-sync-build-file-list.sh" --include-file "$INCLUDE_FILE" --output-dir "$OUTPUT_DIR"
  else
    exec bash "$(dirname "$0")/template-sync-build-file-list.sh" --exclusions-file "$EXCLUSIONS_FILE" --output-dir "$OUTPUT_DIR"
  fi
fi
