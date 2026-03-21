#!/bin/sh
# If TF_VAR_github_token is unset, use GITHUB_TOKEN (Docker / local .env).
if [ -z "${TF_VAR_github_token:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  export TF_VAR_github_token="$GITHUB_TOKEN"
fi
exec terraform "$@"
