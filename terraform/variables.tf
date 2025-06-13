# variables.tf
# No variables needed for this simple example

variable "github_token" {
  description = "GitHub token for authentication"
  type        = string
  sensitive   = true
}

variable "repositories" {
  description = "Map of repositories to manage"
  type = map(object({
    name        = string
    description = string
    visibility  = string
    is_template = bool
    template = object({
      repository = string
    })
  }))
  default = {
    "cursor" = {
      name        = "template-cursor"
      description = "Cursor repository created from template"
      visibility  = "public"
      is_template = true
      template = {
        repository = "template-template"
      }
    }
    "nuxt-ucda" = {
      name        = "nuxt-ucda"
      description = "UCDA Nuxt repository created from template-cursor"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "invoice-x12-converter" = {
      name        = "invoice-x12-converter"
      description = "Invoice to X12 repository created from template-cursor"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "comic-reader" = {
      name        = "comic-reader"
      description = "A nuxt PWA to help read comics"
      visibility  = "public"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "rfp-langchain" = {
      name        = "rfp-langchain"
      description = "A rfp built on langchain"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "gallery" = {
      name        = "gallery"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
  }
}

variable "repository_settings" {
  description = "Default settings for all repositories"
  type = object({
    has_issues   = bool
    has_projects = bool
    has_wiki     = bool
  })
  default = {
    has_issues   = false
    has_projects = false
    has_wiki     = false
  }
}
