#!/usr/bin/env bash
# Synced from template — do not edit. Changes will be overwritten on the next sync.
# Ensure .terraform.lock.hcl is in sync with provider requirements (backend=false view).
#
# Design: Committed lock file must be from terraform init -backend=false so it only lists
# required_providers (no backend-only provider). Pre-commit and CI run this same check. If
# the lock file is wrong (e.g. has extra provider from 'make init'), we overwrite it and
# exit 1 so you commit the fix — local and GHA CI then give equivalent results. Regenerate
# with make lockfile. See .github/docs/TERRAFORM_CI_DESIGN.md.
#
# Usage: run from repo root. Requires terraform on PATH; if missing, exit 0 (CI without Terraform).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if ! command -v terraform &>/dev/null; then
  echo "terraform not on PATH; skipping lockfile check (install Terraform to enforce locally)." >&2
  exit 0
fi

# Use a temp data dir so we don't touch repo .terraform or need backend creds.
export TF_DATA_DIR="${TF_DATA_DIR:-$(mktemp -d -t tf-lockfile.XXXXXXXXXX)}"

# Check with readonly first; if that fails, fix the lock file and exit 1 so pre-commit fails and you can commit the fix.
if ! terraform -chdir=terraform init -backend=false -input=false -lockfile=readonly 2>&1; then
  echo "terraform lockfile out of sync (e.g. extra backend-only provider). Regenerating with init -backend=false..." >&2
  terraform -chdir=terraform init -backend=false -input=false
  echo "Updated terraform/.terraform.lock.hcl. Add and commit it, then re-run pre-commit." >&2
  exit 1
fi
