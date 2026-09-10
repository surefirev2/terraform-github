# Dockerfile
FROM hashicorp/terraform:1.16.1

# curl required for null_resource.fork local-exec (GitHub API fork/rename)
RUN apk add --no-cache curl

COPY docker/terraform-entrypoint.sh /usr/local/bin/terraform-entrypoint.sh
RUN chmod +x /usr/local/bin/terraform-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/terraform-entrypoint.sh"]
