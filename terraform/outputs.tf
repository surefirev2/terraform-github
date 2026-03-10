# outputs.tf
output "repository_urls" {
  description = "URLs of the created repositories"
  value       = { for k, v in github_repository.repos : k => v.html_url }
}

output "repository_names" {
  description = "Names of the created repositories"
  value       = { for k, v in github_repository.repos : k => v.full_name }
}

output "forked_repository_urls" {
  description = "URLs of repositories forked into the organization"
  value       = { for k, v in data.github_repository.forked : k => v.html_url }
}
