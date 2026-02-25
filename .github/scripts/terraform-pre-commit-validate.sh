#!/usr/bin/env bash
# Synced from template — do not edit. Changes will be overwritten on the next sync.
# Run terraform init -backend=false and terraform validate so pre-commit passes in CI
# without backend credentials. Uses a temp copy so we don't mutate the repo's .terraform.
# Design: same idea as lockfile check (backend=false); see .github/docs/TERRAFORM_CI_DESIGN.md.
set -e
REPO_ROOT="$(git rev-parse --show-toplevel)"
SOURCE_DIR="${REPO_ROOT}/terraform"
IMAGE="${TERRAFORM_IMAGE:-hashicorp/terraform:1.14}"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cp -a "${SOURCE_DIR}/." "$WORK_DIR"
# Exclude .terraform so we get a clean init (no existing backend)
rm -rf "$WORK_DIR/.terraform" "$WORK_DIR/.terraform.lock.hcl"
cp "${SOURCE_DIR}/.terraform.lock.hcl" "$WORK_DIR/"

# Run as current user so trap can remove the temp dir (Docker default is root)
USER_ID=$(id -u)
GROUP_ID=$(id -g)
docker run --rm -u "${USER_ID}:${GROUP_ID}" -v "${WORK_DIR}:/workspace" -w /workspace "$IMAGE" init -backend=false -input=false
docker run --rm -u "${USER_ID}:${GROUP_ID}" -v "${WORK_DIR}:/workspace" -w /workspace "$IMAGE" validate
