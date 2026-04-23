# Dockerfile
FROM hashicorp/terraform:1.14.9

# curl required for null_resource.fork local-exec (GitHub API fork/rename)
RUN apk add --no-cache curl

COPY docker/terraform-entrypoint.sh /usr/local/bin/terraform-entrypoint.sh
RUN chmod +x /usr/local/bin/terraform-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/terraform-entrypoint.sh"]
