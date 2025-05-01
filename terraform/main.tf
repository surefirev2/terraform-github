terraform {
  backend "http" {
    address        = "https://api.tfstate.dev/github/v1"
    lock_address   = "https://api.tfstate.dev/github/v1/lock"
    unlock_address = "https://api.tfstate.dev/github/v1/lock"
    lock_method    = "PUT"
    unlock_method  = "DELETE"
    username       = "surefirev2/template-1-terraform"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
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

resource "github_repository" "cursor" {
  name        = "template-cursor"
  description = "Cursor repository created from template"
  visibility  = "public"

  template {
    owner      = "surefirev2"
    repository = "template-template"
  }

  has_issues   = false
  has_projects = false
  has_wiki     = false
}
