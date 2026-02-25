#!/usr/bin/env sh
# Parse Terraform state lock "Created" time from plan/apply error output.
# Usage: terraform-lock-age.sh [file]
#   If file is given, read from file; otherwise stdin.
#   Outputs the lock creation time as Unix epoch (seconds), or nothing if unparseable.

set -e

if [ -n "$1" ] && [ -r "$1" ]; then
  input=$(cat "$1")
else
  input=$(cat)
fi

# Match "Created:   2026-02-25 01:08:46.530591151 +0000 UTC" and extract date/time.
created_line=$(echo "$input" | grep -E 'Created:[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
[ -z "$created_line" ] && exit 0

# Strip "Created:" and leading spaces; take first two fields (date and time up to optional decimal).
# e.g. "2026-02-25 01:08:46.530591151" or "2026-02-25 01:08:46"
date_part=$(echo "$created_line" | sed -n 's/.*Created:[[:space:]]*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}[[:space:]][0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)[.0-9]*.*/\1/p')
[ -z "$date_part" ] && exit 0

# Convert to epoch (GNU date in CI; no-op on BSD).
epoch=$(date -d "$date_part UTC" +%s 2>/dev/null) && echo "$epoch"
