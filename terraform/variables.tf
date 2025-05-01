# variables.tf
# No variables needed for this simple example

variable "github_token" {
  description = "GitHub token for authentication"
  type        = string
  sensitive   = true
}
