#!/usr/bin/env bash
# Import existing GitHub resources into S3-backed state (integrations/github ~5.14).
# Order: repositories -> null_resource.fork (targeted apply) -> branch protections.
# Prerequisites: .env with TF_VAR_github_token and AWS_* ; make init succeeded.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
[[ -f .env ]] || {
  echo ".env not found (build with terraform-load-env.sh or copy from .env.example)" >&2
  exit 1
}

run_tf() {
  docker run --rm \
    --env-file .env \
    -e HOME=/workspace \
    -u "$(id -u):$(id -g)" \
    -v "${REPO_ROOT}/terraform:/workspace" \
    -w /workspace \
    terraform "$@"
}

FORK_KEY="ralph-taskmaster-ai"

# --- 1) github_repository.repos ---
declare -a REPO_KEYS=(
  cursor nuxt-ucda invoice-x12-converter comic-reader rfp-langchain gallery tutorv1 repo-scan
  info-amalgamator lumen math_spike1 math_spike2 math_langchain math_instructure math_nuxt_chat_ui
  private_ai terraform-cloudflare repo-sync-action
)
declare -a REPO_NAMES=(
  template-cursor nuxt-ucda invoice-x12-converter comic-reader rfp-langchain gallery tutorv1 repo-scan
  info-amalgamator lumen math_spike1 math_spike2 math_langchain math_instructure math_nuxt_chat_ui
  private_ai terraform-cloudflare repo-sync-action
)

for i in "${!REPO_KEYS[@]}"; do
  key="${REPO_KEYS[$i]}"
  name="${REPO_NAMES[$i]}"
  echo "==> import github_repository.repos[\"${key}\"] ${name}"
  run_tf import "github_repository.repos[\"${key}\"]" "${name}"
done

# --- 2) null_resource.fork (not importable; provisioner exits early if repo exists) ---
echo "==> apply -target null_resource.fork[\"${FORK_KEY}\"]"
run_tf apply -target="null_resource.fork[\"${FORK_KEY}\"]" -auto-approve

# --- 3) github_branch_protection.default_branch (public repos; pattern main) ---
declare -a PUBLIC_KEYS=(cursor comic-reader repo-sync-action)
declare -a PUBLIC_NAMES=(template-cursor comic-reader repo-sync-action)
for i in "${!PUBLIC_KEYS[@]}"; do
  key="${PUBLIC_KEYS[$i]}"
  name="${PUBLIC_NAMES[$i]}"
  echo "==> import github_branch_protection.default_branch[\"${key}\"] ${name}:main"
  run_tf import "github_branch_protection.default_branch[\"${key}\"]" "${name}:main"
done

# --- 4) Fork branch protection (pattern = default branch; this fork uses master) ---
FORK_REPO="ralph-taskmaster-ai"
BRANCH="${FORK_DEFAULT_BRANCH:-master}"
echo "==> import github_branch_protection.forked_default_branch[\"${FORK_KEY}\"] ${FORK_REPO}:${BRANCH}"
run_tf import "github_branch_protection.forked_default_branch[\"${FORK_KEY}\"]" "${FORK_REPO}:${BRANCH}"

echo "Imports complete. Run: make plan"
