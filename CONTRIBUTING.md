# Contributing to aidome-blueprints

Thanks for contributing. This is a collection of **production-ready deployment blueprints** for the AIdome platform — changes here affect how customers install and operate AIdome, so we hold a high bar for clarity, safety, and idempotency.

## Before you start

1. Read [`AGENTS.md`](AGENTS.md) — it is the single source of truth for conventions and is shared by humans **and** AI assistants (GitHub Copilot, Codex, Claude Code).
2. Read the path-scoped instructions in [`.github/instructions/`](.github/instructions/) for whatever you're touching (Terraform, Ansible, CloudFormation, Helm, etc.).
3. Read the blueprint's `README.md` to understand its existing contract with customers.

## Workflow

1. Fork or branch from `main`. Branch names: `feat/<blueprint>-<slug>`, `fix/<blueprint>-<slug>`, `docs/<scope>`, `ci/<scope>`.
2. Make changes scoped to a **single blueprint** when possible; cross-cutting changes go under `shared/` or `docs/`.
3. Run the relevant local checks — see [`AGENTS.md § 5 Common Commands`](AGENTS.md#5-common-commands).
4. Open a PR. Fill in security impact if you touch IAM, security groups, NACLs, secrets, or TLS.
5. Wait for CI (`.github/workflows/validate.yml`) to pass.

## Pre-PR checklist

- [ ] Formatters / linters clean: `terraform fmt -check`, `tflint`, `ansible-lint`, `yamllint`, `cfn-lint`, `helm lint`, `shellcheck`, `markdownlint`
- [ ] `terraform validate` / `helm template … | kubeconform -strict` / `ansible-playbook --syntax-check` pass
- [ ] Security scan clean (`tfsec`, `checkov`, or `cfn-nag` as appropriate)
- [ ] Every new `variable` / `output` / CloudFormation `Parameter` has `description` and `type` / constraints
- [ ] Blueprint `README.md` updated if user-facing behaviour changed
- [ ] Root `README.md` updated if files or directories were added/renamed/removed
- [ ] Architecture diagram (`architecture.png`) updated if topology changed (re-export from `assets/diagrams/`)
- [ ] No secrets committed (`gitleaks detect` is clean)
- [ ] `.gitignore` still excludes `.terraform/`, `*.tfstate*`, `*.tfvars` (except `*.tfvars.example`), `*.retry`, `kubeconfig`, `*.pem`, `*.key`

## Security disclosures

Please **do not** open public issues for vulnerabilities. Email the maintainers listed in `CODEOWNERS` (or open a private security advisory via GitHub).

## Using AI assistants

This repo is configured for GitHub Copilot, OpenAI Codex / Codex CLI, and Claude Code. If you use one:

- Let it read [`AGENTS.md`](AGENTS.md) first. All three tools pick it up (Claude via [`CLAUDE.md`](CLAUDE.md), Copilot via [`.github/copilot-instructions.md`](.github/copilot-instructions.md)).
- For multi-step work, consider invoking the [planning-with-files skill](skills/planning-with-files/) — it keeps long sessions coherent.
- You are still responsible for every line that lands in the PR. Review AI suggestions against the path-scoped instructions.

## Code of conduct

Be kind. Assume good intent. Prefer concrete, actionable feedback on PRs.

## License

By contributing, you agree your work is licensed under the terms in [LICENSE](LICENSE).
