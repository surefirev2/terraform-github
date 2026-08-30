# Terraform CI design (template)

This repository follows the **template-1-terraform** pattern:

1. **Checkout** and install **1Password CLI**.
2. **`.github/terraform-env-vars.conf`** lists variables; **`terraform-load-env.sh`** resolves `op://` references using `OP_SERVICE_ACCOUNT_TOKEN` and writes **`.env`** at the repo root.
3. **`make build-image`** / **`make init`** use Docker ([`Dockerfile`](../../Dockerfile)) so Terraform version matches locally and in CI (see `hashicorp/terraform` image tag).
4. **Remote state** uses the **S3** backend with encryption and **`use_lockfile`** (see [`terraform/main.tf`](../../terraform/main.tf)).
5. **Lock handling**: `terraform-wait-unlock.sh` and related scripts run **`terraform plan`** in a loop when needed; S3 native lockfiles are still subject to concurrent runs—scripts parse Terraform lock errors from plan output.

## Apply policy (required)

- **Plan** on pull requests against `main`; **apply** only on **push to `main`** after merge ([`terraform.yaml`](../workflows/terraform.yaml)).
- Do **not** apply from a laptop or agent session (`make apply` / `terraform apply`). Local plan/validate is fine; shipping happens via PR → merge → CI apply.
- Agents: see [`AGENTS.md`](../../AGENTS.md).

**Pre-commit**: `terraform-lockfile` runs `terraform init -backend=false -lockfile=readonly` in `terraform/` so `.terraform.lock.hcl` tracks providers only (no backend credentials required).

For 1Password field names, IAM, and bucket/key for this repo, see [`terraform-1password.md`](../../terraform-1password.md).
