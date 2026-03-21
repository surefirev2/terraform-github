#!/bin/sh
# Map GITHUB_TOKEN to TF_VAR_github_token so .env can use either (CI often sets TF_VAR_github_token via terraform-load-env.sh).
if [ -z "${TF_VAR_github_token:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  export TF_VAR_github_token="$GITHUB_TOKEN"
fi
exec terraform "$@"
