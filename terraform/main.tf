terraform {
  backend "http" {
    address        = "https://api.tfstate.dev/github/v1"
    lock_address   = "https://api.tfstate.dev/github/v1/lock"
    unlock_address = "https://api.tfstate.dev/github/v1/lock"
    lock_method    = "PUT"
    unlock_method  = "DELETE"
    username       = "surefirev2/terraform-github"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "< 5.15.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "github" {
  owner = "surefirev2"
  token = var.github_token
}

# Fork external repositories into the organization (GitHub API; no provider resource for fork).
# If name != source_repo, renames the fork in the org to the desired name.
resource "null_resource" "fork" {
  for_each = { for f in var.repository_forks : coalesce(f.name, f.source_repo) => f }

  triggers = {
    source = "${each.value.source_owner}/${each.value.source_repo}"
    name   = coalesce(each.value.name, each.value.source_repo)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      SOURCE_OWNER="${each.value.source_owner}"
      SOURCE_REPO="${each.value.source_repo}"
      TARGET_NAME="${coalesce(each.value.name, each.value.source_repo)}"
      AUTH="Authorization: token $GITHUB_TOKEN"
      ACCEPT="Accept: application/vnd.github.v3+json"
      CODE=$(curl -sS -o /dev/null -w "%%{http_code}" "https://api.github.com/repos/surefirev2/$TARGET_NAME" -H "$AUTH" -H "$ACCEPT")
      [ "$CODE" = "200" ] && exit 0
      # Fork into org
      curl -sSf -X POST -H "$AUTH" -H "$ACCEPT" -H "Content-Type: application/json" \
        -d '{"organization":"surefirev2"}' \
        "https://api.github.com/repos/$SOURCE_OWNER/$SOURCE_REPO/forks" >/dev/null
      # Rename in org if name != source (idempotent on 422)
      if [ "$TARGET_NAME" != "$SOURCE_REPO" ]; then
        if ! curl -sSf -X PATCH -H "$AUTH" -H "$ACCEPT" -H "Content-Type: application/json" \
          -d "{\"name\":\"$TARGET_NAME\"}" \
          "https://api.github.com/repos/surefirev2/$SOURCE_REPO"; then
          curl -sSf -o /dev/null "https://api.github.com/repos/surefirev2/$TARGET_NAME" -H "$AUTH" -H "$ACCEPT" || exit 1
        fi
      fi
    EOT
    environment = {
      GITHUB_TOKEN = var.github_token
    }
  }
}

# Look up forked repos so we can apply branch protection (after fork exists)
data "github_repository" "forked" {
  for_each   = { for f in var.repository_forks : coalesce(f.name, f.source_repo) => f }
  full_name  = "surefirev2/${coalesce(each.value.name, each.value.source_repo)}"
  depends_on = [null_resource.fork]
}

# Branch protection for forked repos (default branch e.g. main or master)
resource "github_branch_protection" "forked_default_branch" {
  for_each = { for f in var.repository_forks : coalesce(f.name, f.source_repo) => f }

  repository_id = data.github_repository.forked[each.key].node_id
  pattern       = data.github_repository.forked[each.key].default_branch

  required_status_checks {
    strict   = true
    contexts = ["pre-commit"]
  }

  enforce_admins = true
}

# Create organization-wide branch protection
resource "github_branch_protection" "default_branch" {
  for_each = { for k, v in var.repositories : k => v if v.visibility != "private" }

  repository_id = github_repository.repos[each.key].node_id
  pattern       = "main"

  required_status_checks {
    strict   = true
    contexts = ["pre-commit"]
  }

  enforce_admins = true
}

# Create and manage repositories
resource "github_repository" "repos" {
  for_each = var.repositories

  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility
  is_template = each.value.is_template

  dynamic "template" {
    for_each = each.value.template.repository != "" ? [each.value.template] : []
    content {
      owner      = "surefirev2"
      repository = template.value.repository
    }
  }

  has_issues   = var.repository_settings.has_issues
  has_projects = var.repository_settings.has_projects
  has_wiki     = var.repository_settings.has_wiki

  allow_auto_merge       = true
  allow_merge_commit     = false
  allow_update_branch    = true
  delete_branch_on_merge = true

  # Skip reading vulnerability_alerts so plan/apply works when the token or org
  # cannot access the endpoint (403: Resource not accessible by integration).
  # We do not manage vulnerability_alerts; lifecycle.ignore_changes already
  # ignores drift for vulnerability_alerts and security_and_analysis.
  ignore_vulnerability_alerts_during_read = true

  lifecycle {
    ignore_changes = [
      vulnerability_alerts,
      security_and_analysis,
    ]
  }
}
