#!/usr/bin/env bash
# Ensure .terraform.lock.hcl is present and in sync with provider requirements (pinned providers).
# Run from repo root. Requires terraform on PATH to run the check.
# If terraform is not on PATH, skip (exit 0) so shared pre-commit CI without Terraform still passes.
# The Terraform workflow installs Terraform before running this hook, so the check runs there.
# Exit 1 if lock file would need updating (run 'make init' and commit terraform/.terraform.lock.hcl).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if ! command -v terraform &>/dev/null; then
  echo "terraform not on PATH; skipping lockfile check (install Terraform to enforce locally)." >&2
  exit 0
fi

# Use a temp data dir so we don't touch repo .terraform or need backend creds.
# -backend=false: skip backend; we only verify provider lock file.
# -lockfile=readonly: fail if lock file would need to be updated (ensures providers are pinned and committed).
export TF_DATA_DIR="${TF_DATA_DIR:-$(mktemp -d -t tf-lockfile.XXXXXXXXXX)}"
terraform -chdir=terraform init -backend=false -input=false -lockfile=readonly
