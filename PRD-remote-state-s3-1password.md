# PRD: Terraform remote state on S3 with secrets from 1Password (GitHub Actions)

| Field | Value |
|-------|--------|
| **Status** | Adopted (template + downstream alignment) |
| **Audience** | Maintainers of repositories that consume **template-1-terraform**–synced workflows (`terraform-github`, `terraform-cloudflare`, and similar) |
| **Related** | [.github/docs/TERRAFORM_CI_DESIGN.md](.github/docs/TERRAFORM_CI_DESIGN.md), [terraform-1password.md](terraform-1password.md) |

## 1. Executive summary

**tfstate.dev** (HTTP remote backend) is **unavailable**. We no longer rely on it for Terraform state. State is stored in an **Amazon S3 bucket** using the Terraform **S3 backend**, with **encryption** and **native S3 locking** (`use_lockfile`).

In **GitHub Actions**, the only long-lived secret we store in GitHub is the **1Password service account token** (`OP_SERVICE_ACCOUNT_TOKEN`). The workflow uses the **1Password CLI** to resolve `op://` references and build a `.env` file consumed by `make` / Docker. That includes **AWS access keys** (for S3 state) and the **GitHub PAT** (for Terraform GitHub provider usage), both read from a designated **1Password item**—not from separate GitHub secrets for AWS.

Child repositories that receive synced workflows from this template should mirror this model: **configure 1Password**, **wire `OP_SERVICE_ACCOUNT_TOKEN`**, and **ensure IAM + backend blocks** in Terraform match their environment.

## 2. Problem statement

1. **Service failure:** The previous **HTTP backend** (`api.tfstate.dev`) is **down**; we cannot migrate state off it with `terraform init -migrate-state`. Each repo must treat remote state as **new in S3** unless they have an independent export (many will not).
2. **Secret sprawl:** Storing many provider tokens as raw GitHub secrets does not scale and duplicates what we already keep in **1Password**.
3. **Consistency:** Downstream repos share **workflows and scripts** from this template; they need a **single story** for how state and credentials work so onboarding and incidents stay predictable.

## 3. Goals

- **G1 — Reliable state:** Use **S3** as the Terraform remote backend with **encryption** and **locking** appropriate for CI and local use.
- **G2 — One GitHub secret for vault access:** Use **`OP_SERVICE_ACCOUNT_TOKEN`** so CI can read **AWS** and **GitHub** credentials from **1Password** via `op read`, aligned with existing PAT loading.
- **G3 — Documented child-repo duties:** Clear checklist for repos that sync workflows: what to configure in 1Password, GitHub, IAM, and Terraform `backend` blocks.

## 4. Non-goals

- Rebuilding **tfstate.dev** or re-enabling the HTTP backend.
- Mandating a **single shared state file** for all repositories (each repo keeps its own **`key`** under the shared or org bucket strategy).
- Storing **AWS keys in GitHub Actions** as first-class repository secrets (optional break-glass may exist outside this PRD).

## 5. Solution overview

### 5.1 Remote state: S3 backend

- Terraform `backend "s3"` with at least: **`bucket`**, **`key`** (unique per repository/stack), **`region`**, **`encrypt = true`**, and **`use_lockfile = true`** (Terraform ≥ 1.10 in the image we use—native lock objects in S3, no DynamoDB table required for locking in this model).
- Example shape (values differ per repo):

```hcl
terraform {
  backend "s3" {
    bucket       = "<org-terraform-state-bucket>"
    key          = "github/<org>/<repo>/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

### 5.2 Credentials in CI: 1Password → `.env`

1. Workflow installs **1Password CLI** (`1password/install-cli-action`).
2. Job sets **`OP_SERVICE_ACCOUNT_TOKEN`** from **`secrets.OP_SERVICE_ACCOUNT_TOKEN`** (the only GitHub secret required for vault-backed vars in this design).
3. **`TF_GITHUB_ORG`** and **`TF_GITHUB_REPO`** are set from the GitHub event context.
4. **`.github/scripts/terraform-load-env.sh`** reads **`.github/terraform-env-vars.conf`**:
   - Lines like `VAR=op://vault/item/field` are resolved with `op read`.
   - Literals and copy-from-env lines are written as today.
5. Output is **`.env`** at repo root; **`make`** passes it into the Terraform Docker container.

**Important:** **`terraform-env-vars.conf` is not bulk-synced** from the template to children (it is repo-specific). Child repos must maintain their own file with the same **pattern**: PAT and AWS fields as `op://` references where CI should resolve them.

### 5.3 1Password item (reference model)

Vault/item/field layout is documented in [terraform-1password.md](terraform-1password.md). At minimum the item used for CI should expose:

| Field / label | Purpose |
|---------------|---------|
| `github_classic_token` | GitHub PAT for Terraform provider |
| `AWS_ACCESS_KEY_ID` | IAM access key for S3 state API calls |
| `AWS_SECRET_ACCESS_KEY` | IAM secret for S3 state |

The **service account** behind `OP_SERVICE_ACCOUNT_TOKEN` must have **read** access to these fields.

### 5.4 AWS IAM

The IAM principal whose keys live in 1Password needs **least-privilege S3** on the state bucket (and object prefix): `ListBucket` with appropriate prefix conditions, `GetObject` / `PutObject` / `DeleteObject` for state and lock objects. Exact ARNs are bucket- and prefix-specific; see your org’s IAM policy reviews.

## 6. Requirements for child repositories

Repositories that **pull synced workflows** from **template-1-terraform** should:

1. **Terraform** — Define **`backend "s3"`** with a **unique `key`** per repo (or per stack), consistent with org naming.
2. **1Password** — Store AWS keys and PAT on the item your `op://` paths reference; grant the **GitHub Actions service account** read access.
3. **GitHub** — Set **`OP_SERVICE_ACCOUNT_TOKEN`** in repository (or org) secrets.
4. **Local file** — Maintain **`.github/terraform-env-vars.conf`** with `op://` lines (and literals like `AWS_DEFAULT_REGION` as needed). Do not commit real secrets.
5. **IAM** — Ensure the IAM user/role matches the bucket and prefix your backend uses.
6. **Docs** — Link maintainers to [terraform-1password.md](terraform-1password.md) and [.github/docs/TERRAFORM_CI_DESIGN.md](.github/docs/TERRAFORM_CI_DESIGN.md).

## 7. Migration and “fresh state”

Because **tfstate.dev** cannot be reached:

- There is **no supported automated migrate** from the old HTTP backend for most repos.
- The first apply against S3 may show **create** for all managed resources. Teams must handle **existing real infrastructure** via **import**, **state surgery**, or coordinated **apply**—case by case.
- Communicate with stakeholders before **apply** on shared environments.

## 8. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| 1Password or service account outage blocks CI | Document break-glass (temporary env / different auth); keep runbooks short. |
| Over-broad IAM | Use prefix-scoped S3 policies; separate bootstrap vs runtime policies where useful. |
| Drift between template and child `terraform-env-vars.conf` | Code review when syncing workflows; optional copy of field names in this PRD / terraform-1password doc. |
| Confusion about GitHub secrets | Single required secret **`OP_SERVICE_ACCOUNT_TOKEN`** for 1Password-backed vars; AWS not duplicated in GitHub. |

## 9. Sync scope (template → children)

Workflows and scripts synced from **template-1-terraform** implement this PRD’s **mechanism**. **Repository-specific** files (e.g. **`terraform-env-vars.conf`**, Terraform **`backend`** `key`, root **`terraform/`** modules) remain **owned by each child repo**. See [template-sync.yml](../template-sync.yml) for what is pushed automatically.

## 10. References

- HashiCorp: [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- 1Password: [Service accounts](https://developer.1password.com/docs/service-accounts/)
- Internal: [terraform-1password.md](terraform-1password.md), [.github/docs/TERRAFORM_CI_DESIGN.md](.github/docs/TERRAFORM_CI_DESIGN.md)

---

*This document is a PRD for alignment across template consumers; update it when the bucket strategy, 1Password item paths, or workflow contract changes.*
