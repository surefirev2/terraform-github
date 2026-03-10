# Dockerfile
FROM hashicorp/terraform:1.14.6

# curl required for null_resource.fork local-exec (GitHub API fork/rename)
RUN apk add --no-cache curl
