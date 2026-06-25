# variables.tf

variable "github_token" {
  description = "GitHub token for authentication"
  type        = string
  sensitive   = true
  default     = ""
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
    "tutorv1" = {
      name        = "tutorv1"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "repo-scan" = {
      name        = "repo-scan"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "info-amalgamator" = {
      name        = "info-amalgamator"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "lumen" = {
      name        = "lumen"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "math_spike1" = {
      name        = "math_spike1"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "math_spike2" = {
      name        = "math_spike2"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "math_langchain" = {
      name        = "math_langchain"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "math_instructure" = {
      name        = "math_instructure"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "math_nuxt_chat_ui" = {
      name        = "math_nuxt_chat_ui"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "math-desktop" = {
      name        = "math-desktop"
      description = "Epiphanie math desktop app"
      visibility  = "private"
      is_template = false
      template = {
        repository = ""
      }
    }
    "private_ai" = {
      name        = "private_ai"
      description = "TBD"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-cursor"
      }
    }
    "terraform-cloudflare" = {
      name        = "terraform-cloudflare"
      description = "Terraform configuration for Cloudflare"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template-1-terraform"
      }
    }
    "repo-sync-action" = {
      name        = "repo-sync-action"
      description = "GitHub Action to sync from any repository to any repository (created from template-template)"
      visibility  = "public"
      is_template = false
      template = {
        repository = "template-template"
      }
    }
    "hockeymind" = {
      name        = "hockeymind"
      description = "HockeyMind"
      visibility  = "private"
      is_template = false
      template = {
        repository = ""
      }
    }
    "ethan_carpentry" = {
      name        = "ethan_carpentry"
      description = "Ethans Carpetnry project"
      visibility  = "private"
      is_template = false
      template = {
        repository = ""
      }
    }
    "comics_tauri" = {
      name        = "comics_tauri"
      description = "Comics"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template_template"
      }
    }
    "comics_self_hosted" = {
      name        = "comics_self_hosted"
      description = "Self-hosted comics stack"
      visibility  = "private"
      is_template = false
      template = {
        repository = "template_template"
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

variable "branch_protection_status_checks" {
  description = "Required status check contexts per repository key (defaults to pre-commit when absent)"
  type        = map(list(string))
  default = {
    hockeymind = ["e2e (blacksmith-4vcpu-ubuntu-2404, 22)"]
  }
}

variable "repository_collaborators" {
  description = "Outside collaborators per repository (keys must match var.repositories)"
  type = map(list(object({
    username   = string
    permission = string # pull, triage, push, maintain, admin
  })))
  default = {
    math_spike2 = [
      {
        username   = "kevinwm0"
        permission = "maintain"
      }
    ]
  }
}

variable "repository_pages" {
  description = "GitHub Pages settings per repository (keys must match var.repositories)"
  type = map(object({
    build_type    = string # legacy or workflow
    source_branch = optional(string, "main")
    source_path   = optional(string, "/")
  }))
  default = {
    math_spike2 = {
      build_type    = "workflow"
      source_branch = "main"
      source_path   = "/"
    }
  }
}

variable "repository_forks" {
  description = "Repositories to fork into the organization. name = repo name in org (defaults to source_repo)."
  type = list(object({
    source_owner = string
    source_repo  = string
    name         = optional(string) # name in org; default source_repo
  }))
  default = [
    {
      source_owner = "Th0rgal"
      source_repo  = "open-ralph-wiggum"
      name         = "ralph-taskmaster-ai"
    }
  ]
}
