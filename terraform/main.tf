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
  }
}

provider "github" {
  owner = "surefirev2"
  token = var.github_token
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

  lifecycle {
    ignore_changes = [
      vulnerability_alerts,
      security_and_analysis,
    ]
  }
}
