---
applyTo: '.github/workflows/*.yml, .github/workflows/*.yaml'
description: 'Best practices for GitHub Actions workflows used to validate aidome-blueprints and publish docs — covering pinning, least privilege, caching, matrix strategies, and concurrency.'
---

<!--
Adapted from: https://github.com/github/awesome-copilot/blob/main/instructions/github-actions-ci-cd-best-practices.instructions.md
License: MIT (github/awesome-copilot)
Trimmed and focused on this repo's CI surface.
-->

# GitHub Actions CI/CD Best Practices

## Mission

This repo has two workflows: `validate.yml` (IaC lint/validate on every PR) and `publish-docs.yml` (MkDocs publishing). Keep them fast, deterministic, and secure.

## Workflow Structure

- **`name`** at the top; meaningful and matching the filename.
- **`on`**: use `pull_request:` for validation and `push:` to `main` (+ `workflow_dispatch:`) for publishing. Avoid `on: [push]` without filters.
- **`concurrency`**: set `group: ${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true` for PR workflows.
- **`permissions`**: always declare the minimum at the workflow or job level. Default to `contents: read`. Only grant `id-token: write`, `pull-requests: write`, `pages: write`, etc., to the specific job that needs them.

## Jobs and Steps

- **Pin action versions by commit SHA**, not by tag, for third-party actions. Use full-length SHA and add a comment with the version tag.
  - `uses: actions/checkout@<40-char-sha> # v4.1.7`
- **Use official actions** where available (`actions/checkout`, `actions/setup-*`, `hashicorp/setup-terraform`).
- **Matrix** across Terraform versions / OS only when it catches real bugs; otherwise keep CI fast.
- **Timeouts**: set `timeout-minutes` on every job (typical: 10–20).
- **Fail-fast**: default `true` for matrices that share a root cause; `false` when you want full coverage per matrix cell.

## Secrets and Variables

- **Never echo secrets.** GitHub redacts them, but transformations (base64, JSON-parse) can expose them.
- Use **environment secrets** for prod-only credentials and **repo secrets** for shared CI tooling.
- For AWS, prefer **OIDC** (`aws-actions/configure-aws-credentials` with `role-to-assume`) over long-lived access keys. Grant `permissions: id-token: write` only on the specific job.
- Do not put secrets in `env:` at the workflow level; scope them to the step.

## Caching

- Cache language toolchains and dependency trees:
  - `actions/setup-python` with `cache: 'pip'`
  - `actions/setup-node` with `cache: 'npm'`
  - `hashicorp/setup-terraform` provides its own cache keying
- Include the lockfile (`requirements.txt`, `package-lock.json`, `.terraform.lock.hcl`) in the cache key.

## IaC-specific steps

Recommended jobs for `validate.yml`:

1. **Terraform fmt & validate** across every `terraform/` directory and `shared/terraform-modules/`:
   - `terraform fmt -check -recursive .`
   - `terraform init -backend=false`
   - `terraform validate`
   - `tflint --recursive` (optional)
   - `tfsec .` or `checkov -d .` (pick one; pin to a specific release)
2. **CloudFormation**: `cfn-lint blueprints/02-aws-ec2/cloudformation/*.yaml`
3. **Ansible**: `yamllint` + `ansible-lint` + `ansible-playbook --syntax-check`
4. **Helm / Kubernetes**: `helm lint` + `helm template ... | kubeconform -strict`
5. **Shell scripts**: `shellcheck $(git ls-files '*.sh')`
6. **Markdown**: `markdownlint '**/*.md' --ignore node_modules`

## Deployment Strategies

For `publish-docs.yml`:
- Build once, upload artifact (`actions/upload-pages-artifact`), deploy (`actions/deploy-pages`).
- Guard with `if: github.ref == 'refs/heads/main'` on deploy jobs.
- Keep the build job read-only; put `pages: write, id-token: write` only on the deploy job.

## Observability

- Always surface useful error output from linters (`ansible-lint -p`, `tflint --format compact`, `cfn-lint -f pretty`).
- Use `::error file=...,line=...` annotations so violations appear in the Files Changed tab.

## Checklist

- [ ] `name`, `on`, `concurrency`, and workflow-level `permissions` are declared
- [ ] All third-party actions pinned by SHA
- [ ] Job-level `timeout-minutes` set
- [ ] Secrets are OIDC where possible; no long-lived keys for deploy jobs
- [ ] Dependency cache keyed on a lockfile
- [ ] Linters output actionable annotations
- [ ] Deploy steps guarded by `ref` and `environment`
