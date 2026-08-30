# Agent notes (terraform-github)

## Terraform apply: PR / CI only

**Do not run `make apply` (or `terraform apply`) locally.** Applies run only via GitHub Actions after a PR merges to `main` (see [`.github/workflows/terraform.yaml`](.github/workflows/terraform.yaml)).

Allowed locally (with `.env` / 1Password as needed):

- `make plan` / `make validate` / `make init`
- Read-only state inspection (`make state-list`)
- Imports that prepare state for a follow-up PR (`scripts/terraform-import-existing.sh`), then land config changes through a PR so CI applies

Workflow for infrastructure changes:

1. Feature branch + PR
2. Review the plan posted on the PR by CI
3. Merge to `main` → CI applies

Emergency unlocks use [`.github/workflows/terraform-force-unlock.yaml`](.github/workflows/terraform-force-unlock.yaml) or documented ops paths — not a substitute for shipping config via PR.

More context: [`.github/docs/TERRAFORM_CI_DESIGN.md`](.github/docs/TERRAFORM_CI_DESIGN.md), [`terraform-1password.md`](terraform-1password.md).
