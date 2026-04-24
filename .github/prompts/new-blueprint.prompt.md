---
mode: 'agent'
description: 'Scaffold a new numbered blueprint directory under blueprints/ with README, architecture placeholder, and tool-specific subdirectories.'
---

# Prompt: New Blueprint

You are adding a new blueprint to `aidome-blueprints`. Before writing any files, ask the user for:

1. **Next free blueprint number** (inspect existing `blueprints/NN-*/` directories).
2. **Slug** (lowercase, hyphen-separated — e.g., `gcp-gke`, `azure-aks`, `on-prem-vsphere`).
3. **Complexity** (`Beginner` / `Intermediate` / `Advanced` / `Expert`).
4. **Cloud / target** (AWS / GCP / Azure / On-prem / Air-gapped / None).
5. **HA?** (yes / no).
6. **Primary tooling** (any of: Terraform, CloudFormation, Ansible, Helm, Docker Compose).
7. **Use-case sentence** (one line for the README table in the root README).

Then:

## Scaffold

Create this structure under `blueprints/NN-<slug>/`:

```
blueprints/NN-<slug>/
├── README.md                 ← uses the template below
├── architecture.png          ← placeholder; export from assets/diagrams/
└── <tool-dirs>               ← one or more of:
    ├── terraform/            ← providers.tf, variables.tf, main.tf, outputs.tf, versions.tf
    ├── cloudformation/       ← *.yaml with cfn-lint-clean content
    ├── ansible/              ← inventories/, group_vars/, playbooks/, roles/
    ├── helm/                 ← Chart.yaml, values.yaml, templates/
    └── scripts/              ← cloud-init.yaml, post-install.sh
```

## Blueprint README template

```markdown
# NN · <Title>

> **Complexity:** <⭐…> <Beginner|Intermediate|Advanced|Expert> | **Cloud:** <cloud> | **HA:** <✅|❌>

One-paragraph description of what this blueprint provisions and who it is for.

## Architecture

![Architecture diagram](./architecture.png)

## Prerequisites

- <Tool versions>
- <Cloud account requirements, IAM permissions>
- <Network prerequisites>

## Deploy

### Option A: <primary tool>
...

### Option B: <alternative tool> (optional)
...

## Verify

- `<health-check command>`
- Expected output: ...

## Teardown

- `<destroy command>`

## Security notes

- IAM permissions required (minimal policy JSON)
- Secret handling
- Long-lived credentials and how to rotate them
- Network posture assumed
```

## After scaffolding

1. Update the root [`README.md`](../../README.md) blueprint comparison table and repository layout.
2. Ensure [`docs/choosing-a-blueprint.md`](../../docs/choosing-a-blueprint.md) mentions when to pick this blueprint.
3. Update [`.github/workflows/validate.yml`](../workflows/validate.yml) so the new blueprint is covered by the relevant lint / validate steps.
4. Follow the path-scoped instructions in [`.github/instructions/`](../instructions/) for each tool you use.
5. Do **not** run `terraform apply` / `ansible-playbook` / `helm install` against real infrastructure. Use `plan`, `--check`, and `--dry-run`.

Report back with a summary of files created and any open questions for the maintainer.
