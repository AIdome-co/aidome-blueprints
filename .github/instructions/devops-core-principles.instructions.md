---
applyTo: '*'
description: 'Foundational DevOps principles (CALMS framework + DORA metrics) to guide AI agents toward effective software delivery in IaC contexts.'
---

<!--
Source: https://github.com/github/awesome-copilot/blob/main/instructions/devops-core-principles.instructions.md
License: MIT (github/awesome-copilot)
Condensed for aidome-blueprints — retaining the framework summaries.
-->

# DevOps Core Principles

## Mission

When generating or reviewing changes in this repository, consider how they align with the CALMS pillars and the DORA metrics. Blueprints are the contract between AIdome and its customers; they must be **reliable, observable, secure, and easy to roll forward or back**.

## CALMS Framework

### C — Culture
- Shared responsibility across Dev, Ops, Security, and (for customer-facing blueprints) Customer Success.
- Blameless post-mortems. When a blueprint breaks a customer install, fix the blueprint and the runbook — not the person.
- Fast feedback loops: every change runs through `.github/workflows/validate.yml` before merge.

### A — Automation
- **Infrastructure as Code** for everything customers can see: Terraform, CloudFormation, Ansible, Helm.
- **CI/CD** for every blueprint: lint, validate, security-scan on every PR.
- **No manual clicks** in a runbook without a documented automation backlog entry.

### L — Lean
- Small, single-blueprint PRs are strongly preferred over cross-cutting mega-PRs.
- Delete dead code promptly. If a variable/module is unused after refactor, remove it.
- Feature-flag risky blueprint changes (e.g., behind a `var.enable_*` toggle with `default = false`).

### M — Measurement
- Every blueprint must document how a customer can verify it is healthy (health-check command, log path, metric name).
- Blueprints that expose services must emit structured logs to `STDOUT`/`STDERR` and expose Prometheus metrics where applicable.
- Track the four DORA metrics for this repo itself: deploy frequency, lead time, change failure rate, MTTR.

### S — Sharing
- Cross-cutting decisions go in [`docs/architecture-principles.md`](../../docs/architecture-principles.md) and [`docs/security-guidelines.md`](../../docs/security-guidelines.md), not a single blueprint README.
- Any re-usable Terraform pattern belongs in `shared/terraform-modules/`.
- Runbooks and troubleshooting notes belong in the blueprint's `README.md` — not in Slack or private wikis.

## DORA Metrics (target)

| Metric | Target | How to improve |
|--------|--------|----------------|
| **Deployment Frequency** | Per-merge on `main` | Small PRs, automated validation |
| **Lead Time for Changes** | < 1 day | Fast CI, clear review checklist |
| **Change Failure Rate** | < 15 % | Lint + validate + security scan in CI; dry-run on every blueprint change |
| **Mean Time to Recovery** | < 1 h | Clear rollback paths (`terraform apply -refresh-only`, `helm rollback`, `ansible-playbook --tags rollback`) |

## Guidance for Agents

- When generating IaC, default to **idempotent, declarative** constructs. Avoid `local-exec` except for truly one-off bootstrap steps, and always pair with `creates:`/`removes:` for Ansible shell tasks.
- When generating CI, default to **caching dependencies**, **pinning action versions by SHA**, and **using least-privilege `permissions:` at the job level**.
- When generating code that touches secrets, **never** put them in plaintext variables, `tfvars`, default outputs, or log statements. Use AWS Secrets Manager / SSM / Ansible Vault.
- When generating rollback paths, ensure a deterministic way to revert is documented in the blueprint's `README.md`.
