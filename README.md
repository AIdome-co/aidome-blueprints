# aidome-blueprints

Production-ready deployment blueprints for the AIdome platform. Each blueprint is a self-contained reference implementation that can be adopted as-is or used as a starting point for custom deployments.

Pick the blueprint that matches your scale, cloud posture, and operational requirements, then follow the step-by-step guide in its `README.md`.

## Blueprints

| # | Blueprint | Complexity | Target environment | HA | Typical use case |
|---|-----------|------------|--------------------|----|------------------|
| 01 | [Quickstart – Local](blueprints/01-quickstart-local/README.md) | Beginner | Laptop / workstation | No | Evaluation and local development |
| 02 | [AWS EC2](blueprints/02-aws-ec2/README.md) | Intermediate | AWS | No | Customer EC2 prep for AIdome installation |
| 03 | [Single-Node AWS](blueprints/03-single-node-aws/README.md) | Intermediate | AWS | No | Small teams and proof-of-concept deployments |
| 04 | [HA Kubernetes](blueprints/04-ha-kubernetes/README.md) | Advanced | AWS, GCP, or Azure | Yes | Production workloads |
| 05 | [Air-Gapped](blueprints/05-air-gapped/README.md) | Expert | On-prem or private cloud | Yes | Regulated or offline environments |

### 01. Quickstart (Local)

See [`blueprints/01-quickstart-local/README.md`](blueprints/01-quickstart-local/README.md).

Runs the full AIdome stack on a single machine using Docker Compose. No cloud account is required. Intended for first-time evaluation and local development.

Key files:

- [`docker-compose.yml`](blueprints/01-quickstart-local/docker-compose.yml)
- [`architecture.png`](blueprints/01-quickstart-local/architecture.png)

### 02. AWS EC2

See [`blueprints/02-aws-ec2/README.md`](blueprints/02-aws-ec2/README.md).

Provisions a hardened EC2 instance in a private subnet. The instance bootstraps itself via `cloud-init` and is ready for the customer to run `aidome.sh` to install the AIdome product.

Key files:

- [`terraform/`](blueprints/02-aws-ec2/terraform/)
- [`cloudformation/`](blueprints/02-aws-ec2/cloudformation/)
- [`scripts/cloud-init.yaml`](blueprints/02-aws-ec2/scripts/cloud-init.yaml)

### 03. Single-Node AWS

See [`blueprints/03-single-node-aws/README.md`](blueprints/03-single-node-aws/README.md).

Deploys AIdome on a single EC2 instance with Terraform. Suitable for small teams and proof-of-concept deployments that do not require high availability.

Key files:

- [`terraform/`](blueprints/03-single-node-aws/terraform/)
- [`architecture.png`](blueprints/03-single-node-aws/architecture.png)

### 04. HA Kubernetes

See [`blueprints/04-ha-kubernetes/README.md`](blueprints/04-ha-kubernetes/README.md).

Highly available, multi-replica deployment on Kubernetes (EKS, GKE, or AKS). Terraform provisions the underlying infrastructure and Helm charts deploy the AIdome application layer.

Key files:

- [`terraform/`](blueprints/04-ha-kubernetes/terraform/)
- [`helm/`](blueprints/04-ha-kubernetes/helm/)
- [`architecture.png`](blueprints/04-ha-kubernetes/architecture.png)

### 05. Air-Gapped

See [`blueprints/05-air-gapped/README.md`](blueprints/05-air-gapped/README.md).

Installs AIdome in a fully isolated environment with no internet access, using Ansible. Intended for regulated industries and on-premises private-cloud deployments.

Key files:

- [`ansible/`](blueprints/05-air-gapped/ansible/)

## Repository layout

```text
aidome-blueprints/
├── README.md
├── AGENTS.md
├── CLAUDE.md
├── LICENSE
├── CONTRIBUTING.md
├── mkdocs.yml
├── blueprints/
│   ├── 01-quickstart-local/
│   │   ├── README.md
│   │   ├── architecture.png
│   │   └── docker-compose.yml
│   ├── 02-aws-ec2/
│   │   ├── README.md
│   │   ├── cloudformation/
│   │   ├── scripts/
│   │   └── terraform/
│   ├── 03-single-node-aws/
│   │   ├── README.md
│   │   ├── architecture.png
│   │   └── terraform/
│   ├── 04-ha-kubernetes/
│   │   ├── README.md
│   │   ├── architecture.png
│   │   ├── terraform/
│   │   └── helm/
│   └── 05-air-gapped/
│       ├── README.md
│       └── ansible/
├── shared/
│   ├── terraform-modules/
│   └── scripts/
├── docs/
│   ├── choosing-a-blueprint.md
│   ├── architecture-principles.md
│   └── security-guidelines.md
├── assets/
│   └── diagrams/
├── skills/
│   └── planning-with-files/
└── .github/
    ├── copilot-instructions.md
    ├── instructions/
    ├── prompts/
    └── workflows/
        ├── validate.yml
        └── publish-docs.yml
```

## Documentation

| Document | Description |
|----------|-------------|
| [Choosing a Blueprint](docs/choosing-a-blueprint.md) | Decision guide for selecting a blueprint |
| [Architecture Principles](docs/architecture-principles.md) | Design decisions shared across all blueprints |
| [Security Guidelines](docs/security-guidelines.md) | Security best practices and hardening checklist |

## Shared resources

| Path | Description |
|------|-------------|
| [`shared/terraform-modules/`](shared/terraform-modules/) | Reusable Terraform modules shared by the AWS blueprints |
| [`shared/scripts/`](shared/scripts/) | Utility scripts (health checks, migrations, and similar) |
| [`assets/diagrams/`](assets/diagrams/) | Source files for the architecture diagrams |

## AI-assisted contribution

The repository is configured for GitHub Copilot, OpenAI Codex (and Codex CLI), and Claude Code. [`AGENTS.md`](AGENTS.md) is the canonical guide for all three, wired in through:

- [`CLAUDE.md`](CLAUDE.md) for Claude Code
- [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for GitHub Copilot
- `AGENTS.md` itself for Codex, Cursor, Aider, and any other tool that follows the [agents.md](https://agents.md) convention

Path-scoped rules for Terraform, Ansible, Kubernetes, CloudFormation, shell scripts, and security live under [`.github/instructions/`](.github/instructions/) and are applied automatically by Copilot's `applyTo` front matter. Reusable prompts are in [`.github/prompts/`](.github/prompts/). The [planning-with-files skill](skills/planning-with-files/) is available for multi-step tasks.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow, local checks, and pre-PR checklist.

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file.
