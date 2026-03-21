# Terraform + 1Password (CI and local)

This repository loads secrets for Terraform via [`.github/terraform-env-vars.conf`](.github/terraform-env-vars.conf) and [`.github/scripts/terraform-load-env.sh`](.github/scripts/terraform-load-env.sh). See also [PRD-remote-state-s3-1password.md](PRD-remote-state-s3-1password.md).

## 1Password item (CI)

The service account behind `OP_SERVICE_ACCOUNT_TOKEN` must be able to read the vault item referenced by `op://` paths in `terraform-env-vars.conf`. Typical fields:

| Field / label | Purpose |
|---------------|---------|
| `github_classic_token` | GitHub PAT for the Terraform GitHub provider (`GITHUB_PAT` → `TF_VAR_github_token`) |
| `AWS_ACCESS_KEY_ID` | IAM access key for S3 backend API calls |
| `AWS_SECRET_ACCESS_KEY` | IAM secret for S3 backend |
| `AWS_DEFAULT_REGION` (optional) | Region for the S3 state bucket (or set a literal in config) |

## Remote state (S3) — this repo

| Setting | Value |
|---------|--------|
| **Bucket** | `surefirev2-terraform-state` |
| **Key** | `github/surefirev2/terraform-github/terraform.tfstate` |
| **Region** | `us-east-1` |

Edit [`terraform/main.tf`](terraform/main.tf) if your org uses a different bucket, key, or region.

## IAM (least privilege)

The IAM user or role whose keys are in 1Password needs S3 permissions on the state **bucket** and **object prefix** (including `.tflock` / lock objects when using `use_lockfile = true`):

- `s3:ListBucket` on the bucket (optionally scoped with a prefix condition)
- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on `arn:aws:s3:::<bucket>/<prefix>*`

Exact ARNs depend on your bucket and key prefix; have IAM reviewed for your org. If you scope `ListBucket` by `s3:prefix`, the prefix must cover the state **key** in [`terraform/main.tf`](terraform/main.tf) (e.g. another repo’s policy for `template-1-terraform` alone will deny `terraform-github`).

## Local `.env`

For local runs, either:

1. Export `OP_SERVICE_ACCOUNT_TOKEN`, `TF_GITHUB_ORG`, `TF_GITHUB_REPO` and run `.github/scripts/terraform-load-env.sh`, or
2. Maintain a root `.env` (not committed) with the same variables CI would produce, including `AWS_*` and `TF_VAR_github_token`.

See [`.env.example`](.env.example).

## Troubleshooting S3 backend (`terraform init`)

If init fails with `HeadObject` / `403 Forbidden` on the state object, the IAM principal in `.env` cannot read the bucket or prefix. Confirm the bucket name and key in [`terraform/main.tf`](terraform/main.tf) match your org, and that IAM allows at least `s3:ListBucket` (with prefix) and `s3:GetObject` / `s3:PutObject` / `s3:DeleteObject` on the state key and lock objects. A missing object normally returns **404**, not **403**.

## Importing existing GitHub resources

After `make init` succeeds against S3, run [`scripts/terraform-import-existing.sh`](scripts/terraform-import-existing.sh) with `.env` loaded. It imports repositories, applies `null_resource.fork` for the fork, then imports branch protections. The fork repo’s default branch is **`master`** (not `main`); override with `FORK_DEFAULT_BRANCH=...` if needed.

If drift remains (e.g. `ignore_vulnerability_alerts_during_read`), run `make apply` once to sync, then `make plan` should report **No changes**.
