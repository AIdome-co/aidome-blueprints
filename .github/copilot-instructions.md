# GitHub Copilot Instructions

This file is loaded automatically by **GitHub Copilot Chat** and the **GitHub Copilot coding agent** in every conversation about this repository.

All guidance for AI coding agents — Copilot, OpenAI Codex, and Claude Code — is maintained in a single canonical file to keep behaviour consistent across tools.

👉 **Primary reference:** [`AGENTS.md`](../AGENTS.md) at the repository root.

## Quick reminders for Copilot

This is an **Infrastructure-as-Code** repository (Terraform, CloudFormation, Ansible, Helm, Docker Compose). It is **not** an application codebase.

- Respect path-scoped instructions in [`.github/instructions/`](instructions/) — they apply automatically based on their `applyTo` front matter.
- Reusable prompts are in [`.github/prompts/`](prompts/). Invoke them in Copilot Chat with `/` commands (VS Code 1.93+) or paste the body.
- **Never suggest running `terraform apply`, `aws …`, `kubectl apply`, `helm install`, or `ansible-playbook` against live infrastructure** in a response unless the user explicitly asks. Use plan / dry-run / `--check` equivalents.
- **Never hard-code secrets, AWS account IDs, customer identifiers, or private IPs.** Use variables, Secrets Manager/SSM references, or Ansible Vault.
- Pin versions for Terraform, providers, Helm charts, Ansible collections, and container images.
- Format and lint before suggesting a commit: `terraform fmt`, `tflint`, `ansible-lint`, `shellcheck`, `cfn-lint`, `markdownlint`.

For full context, conventions, commands, and PR guidelines, read [`AGENTS.md`](../AGENTS.md).
