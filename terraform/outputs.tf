# outputs.tf
output "repository_url" {
  description = "URL of the created cursor repository"
  value       = github_repository.cursor.html_url
}

output "repository_name" {
  description = "Name of the created cursor repository"
  value       = github_repository.cursor.full_name
}
