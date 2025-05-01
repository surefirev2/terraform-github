# outputs.tf
output "repository_urls" {
  description = "URLs of the created repositories"
  value       = { for k, v in github_repository.repos : k => v.html_url }
}

output "repository_names" {
  description = "Names of the created repositories"
  value       = { for k, v in github_repository.repos : k => v.full_name }
}
