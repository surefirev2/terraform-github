#!/usr/bin/env bash
# Synced from template — do not edit. Changes will be overwritten on the next sync.
# Build .env for Terraform from .github/terraform-env-vars.conf (config-driven secrets).
#
# Design: Single source of truth is the config file; this script is generic and must not
# contain provider- or repo-specific logic (so it can be reverse-synced). Add new vars
# in the repo's terraform-env-vars.conf only. For Terraform variables, put TF_VAR_<name>
# in config (e.g. TF_VAR_cloudflare_api_token=op://...); the script does not derive them.
#
# Config lines: VAR (copy from env) | VAR=literal | VAR=op://vault/item/field (resolve via op CLI).
# Usage: run from repo root. Set TF_GITHUB_ORG, TF_GITHUB_REPO. For op:// set OP_SERVICE_ACCOUNT_TOKEN.
set -euo pipefail

CONFIG="${1:-.github/terraform-env-vars.conf}"
ENV_FILE="${2:-.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "Config not found: $CONFIG" >&2
  exit 1
fi

: "${TF_GITHUB_ORG:?TF_GITHUB_ORG is required}"
: "${TF_GITHUB_REPO:?TF_GITHUB_REPO is required}"

# When we set GITHUB_PAT (from env or op), record so we can write TF_HTTP_PASSWORD / TF_VAR_github_token
github_pat_value=""

write_var() {
  local name="$1" val="$2"
  if [[ "$val" == *$'\n'* ]]; then
    echo "Skipping $name: value contains newline" >&2
    return
  fi
  if [[ "$val" == *[[:space:]#]* ]]; then
    echo "${name}=\"${val}\"" >> "$ENV_FILE"
  else
    echo "${name}=${val}" >> "$ENV_FILE"
  fi
  if [[ "$name" == "GITHUB_PAT" ]]; then
    github_pat_value="$val"
  fi
}

# Start fresh .env
: > "$ENV_FILE"

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue

  if [[ "$line" == *=op://* ]]; then
    # VAR=op://vault/item/field — resolve with 1Password CLI
    name="${line%%=*}"
    ref="${line#*=}"
    if ! command -v op &>/dev/null; then
      echo "op CLI required for $name=op://... (install 1Password CLI)." >&2
      exit 1
    fi
    if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
      echo "OP_SERVICE_ACCOUNT_TOKEN required for $name=op://..." >&2
      exit 1
    fi
    export OP_SERVICE_ACCOUNT_TOKEN
    val="$(op read "$ref")" || { echo "op read failed for $ref" >&2; exit 1; }
    write_var "$name" "$val"
  elif [[ "$line" == *"="* ]]; then
    # VAR=literal (non-op literal; optional support)
    name="${line%%=*}"
    val="${line#*=}"
    write_var "$name" "$val"
  else
    # VAR — copy from environment
    name="$line"
    if [[ -n "${!name:-}" ]]; then
      write_var "$name" "${!name}"
    fi
  fi
done < "$CONFIG"

# Use env GITHUB_PAT if we didn't set it from config (e.g. legacy workflow passing it)
if [[ -z "${github_pat_value:-}" ]] && [[ -n "${GITHUB_PAT:-}" ]]; then
  github_pat_value="$GITHUB_PAT"
fi

# Terraform backend and provider: derive from GITHUB_PAT when set
if [[ -n "${github_pat_value:-}" ]]; then
  echo "TF_HTTP_PASSWORD=${github_pat_value}" >> "$ENV_FILE"
  echo "TF_VAR_github_token=${github_pat_value}" >> "$ENV_FILE"
fi

# Required for backend / init
echo "TF_GITHUB_ORG=${TF_GITHUB_ORG}" >> "$ENV_FILE"
echo "TF_GITHUB_REPO=${TF_GITHUB_REPO}" >> "$ENV_FILE"

echo "Wrote $ENV_FILE from $CONFIG and TF_GITHUB_ORG/TF_GITHUB_REPO."
