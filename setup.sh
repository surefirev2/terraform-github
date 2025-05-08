#!/bin/bash

# Prompt for GitHub token
read -sp "Enter your GitHub Personal Access Token: " GITHUB_TOKEN

echo

# Copy env.template to .env in root
echo "Setting up .env in root directory..."
cp env.template .env
sed -i "s|GITHUB_PAT=.*|GITHUB_PAT=$GITHUB_TOKEN|" .env

echo "Migrating .template scripts in mcp_scripts to .sh and replacing token placeholders..."
for template in mcp_scripts/*.template; do
  base="$(basename "$template" .template)"
  shfile="mcp_scripts/${base}"
  # Ensure the output ends with .sh, but not .sh.sh
  if [[ "$shfile" != *.sh ]]; then
    shfile="${shfile}.sh"
  fi
  sed "s|__GITHUB_TOKEN_PLACEHOLDER__|$GITHUB_TOKEN|g" "$template" > "$shfile"
  chmod +x "$shfile"
  echo "Created $shfile from $template"
done

# Install pre-commit hook
echo "Setting up git pre-commit hook..."
cp mcp_scripts/pre-commit.hook.template .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "Setup complete."
