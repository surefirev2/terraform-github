#!/bin/bash

# Function to get value from .env if it exists
get_env_var() {
  local var_name="$1"
  if [[ -f .env ]]; then
    grep -E "^$var_name=" .env | head -n1 | cut -d'=' -f2-
  fi
}

# Get defaults from .env if available
DEFAULT_GITHUB_PAT=$(get_env_var "GITHUB_PAT")
DEFAULT_ANTHROPIC_API_KEY=$(get_env_var "ANTHROPIC_API_KEY")

# Prompt for GitHub token
if [[ -n "$DEFAULT_GITHUB_PAT" ]]; then
  read -p "Enter your GitHub Personal Access Token [default: $DEFAULT_GITHUB_PAT]: " GITHUB_PAT
  GITHUB_PAT="${GITHUB_PAT:-$DEFAULT_GITHUB_PAT}"
else
  read -sp "Enter your GitHub Personal Access Token: " GITHUB_PAT
  echo
fi

# Prompt for Anthropic API key
if [[ -n "$DEFAULT_ANTHROPIC_API_KEY" ]]; then
  read -p "Enter your Anthropic API Key [default: $DEFAULT_ANTHROPIC_API_KEY]: " ANTHROPIC_API_KEY
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-$DEFAULT_ANTHROPIC_API_KEY}"
else
  read -sp "Enter your Anthropic API Key: " ANTHROPIC_API_KEY
  echo
fi

# Copy env.template to .env in root
echo "Setting up .env in root directory..."
cp env.template .env
sed -i "s|GITHUB_PAT=.*|GITHUB_PAT=$GITHUB_PAT|" .env
if grep -q '^ANTHROPIC_API_KEY=' .env 2>/dev/null; then
  sed -i "s|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY|" .env
else
  echo "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" >> .env
fi

declare -A TEMPLATE_VARS
TEMPLATE_VARS[__GITHUB_TOKEN_PLACEHOLDER__]="$GITHUB_PAT"
TEMPLATE_VARS[__ANTHROPIC_API_KEY_PLACEHOLDER__]="$ANTHROPIC_API_KEY"

# Scan all .template files for unique placeholders
ALL_PLACEHOLDERS=()
for template in mcp_scripts/*.template; do
  echo "Scanning $template for placeholders..."
  while read -r placeholder; do
    if [[ -z "${TEMPLATE_VARS[$placeholder]+x}" ]]; then
      var_name=$(echo "$placeholder" | sed -E 's/^__|_PLACEHOLDER__$//g')
      echo "Found placeholder: $placeholder (variable: $var_name)"
      read -sp "Enter value for $var_name: " value
      echo
      TEMPLATE_VARS[$placeholder]="$value"
      ALL_PLACEHOLDERS+=("$placeholder")
    fi
  done < <(grep -oE '__[A-Z0-9_]+_PLACEHOLDER__' "$template" | sort -u)
done

if [[ ${#ALL_PLACEHOLDERS[@]} -eq 0 ]]; then
  echo "No additional placeholders found in templates."
fi

echo "Migrating .template scripts in mcp_scripts to .sh and replacing token placeholders..."
for template in mcp_scripts/*.template; do
  base="$(basename "$template" .template)"
  shfile="mcp_scripts/${base}"
  # Ensure the output ends with .sh, but not .sh.sh
  if [[ "$shfile" != *.sh ]]; then
    shfile="${shfile}.sh"
  fi
  if [[ -f "$shfile" ]]; then
    echo "$shfile already exists, skipping."
    continue
  fi
  content=$(cat "$template")
  for placeholder in "${!TEMPLATE_VARS[@]}"; do
    content="${content//${placeholder}/${TEMPLATE_VARS[$placeholder]}}"
  done
  echo "$content" > "$shfile"
  chmod +x "$shfile"
  echo "Created $shfile from $template"
done

# Install pre-commit hook
echo "Setting up git pre-commit hook..."
cp mcp_scripts/pre-commit.hook.template .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "Setup complete."
echo

echo "Next steps:"
echo "  1. Run: npm install"
echo "  2. Then initialize Task Master: npx task-master init"
echo
