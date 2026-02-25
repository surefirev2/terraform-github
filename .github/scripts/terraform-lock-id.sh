#!/usr/bin/env sh
# Synced from template — do not edit. Changes will be overwritten on the next sync.
# Parse Terraform state lock ID from plan/apply error output.
# Usage: terraform-lock-id.sh [file]
#   If file is given, read from file; otherwise stdin.
#   Outputs the UUID or nothing.

set -e

if [ -n "$1" ] && [ -r "$1" ]; then
  input=$(cat "$1")
else
  input=$(cat)
fi

echo "$input" | grep -oE 'ID=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 | sed 's/ID=//'
