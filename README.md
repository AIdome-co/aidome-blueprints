# aidome-blueprints

> **Production-ready deployment blueprints for the AIdome platform.**  
> Pick the blueprint that matches your scale, cloud posture, and operational maturity—then follow its step-by-step guide.

---

## 📋 Blueprint Comparison

| # | Blueprint | Status | Complexity | Cloud | HA | Use-case |
|---|-----------|--------|-----------|-------|----|----------|
| 01 | [Quickstart – Local](blueprints/01-quickstart-local/README.md) | ✅ Available | ⭐ Beginner | None (laptop) | ❌ | Evaluation / development |
| 02 | [AWS EC2 – Single Node](blueprints/02-aws-ec2/README.md) | ✅ Available | ⭐⭐ Intermediate | AWS | ❌ | Single hardened EC2 instance — bring your own VPC **or** let Terraform create full networking from scratch |
| 03 | [HA Kubernetes](blueprints/04-ha-kubernetes/README.md) | 📬 Docs pending — contact us | ⭐⭐⭐ Advanced | AWS / GCP / Azure | ✅ | Production workloads requiring high availability and horizontal scale |
| 04 | [Air-Gapped](blueprints/05-air-gapped/README.md) | 📬 Docs pending — contact us | ⭐⭐⭐⭐ Expert | On-prem / private cloud | ✅ | Regulated / offline environments with no internet access |

---

## 🗂️ Repository Layout

```
aidome-blueprints/
├── README.md                         ← You are here
├── AGENTS.md                         ← Canonical guide for AI coding agents
├── CLAUDE.md                         ← Claude Code entry point (→ AGENTS.md)
├── LICENSE
├── CONTRIBUTING.md
├── mkdocs.yml                        ← Docs-site config (activate when ready)
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
│   └── planning-with-files/          ← Agent Skill (SKILL.md + templates)
└── .github/
    ├── copilot-instructions.md       ← GitHub Copilot entry point (→ AGENTS.md)
    ├── instructions/                 ← Path-scoped instructions (.instructions.md)
    ├── prompts/                      ← Reusable prompt files (.prompt.md)
    └── workflows/
        ├── validate.yml
        └── publish-docs.yml
```

---

## 🚀 Blueprints

### 01 · Quickstart – Local

**File:** [`blueprints/01-quickstart-local/README.md`](blueprints/01-quickstart-local/README.md)

Spin up the full AIdome stack on a single laptop using Docker Compose.  
No cloud account required—ideal for first-time evaluation and local development.

**Key files:**
- [`docker-compose.yml`](blueprints/01-quickstart-local/docker-compose.yml)
- [`architecture.png`](blueprints/01-quickstart-local/architecture.png)

---

### 02 · AWS EC2 – Single Node

**File:** [`blueprints/02-aws-ec2/README.md`](blueprints/02-aws-ec2/README.md)

Provision a hardened, private-subnet EC2 instance on AWS.
Cloud-init bootstraps SSH hardening, iptables, fail2ban, Docker Engine, the AWS SSM Agent,
and a dedicated operator user on first boot. Once the instance is ready, the AIdome team
provides credentials and the `aidome.sh` installer to complete the product installation.

This blueprint supports two modes controlled by a single Terraform variable:

| Mode | When to use | What Terraform creates |
|------|-------------|------------------------|
| **Bring Your Own VPC** (`create_vpc = false`, default) | You already have an AWS VPC, subnets, and routing in place | EC2 instance + security group only |
| **Greenfield** (`create_vpc = true`) | Starting fresh on AWS with no existing VPC | Full network stack (VPC, public + private subnets, Internet Gateway, NAT Gateway, route tables) **plus** EC2 instance + security group |

**Key files:**
- [`terraform/`](blueprints/02-aws-ec2/terraform/)
- [`cloudformation/`](blueprints/02-aws-ec2/cloudformation/)
- [`scripts/cloud-init.yaml`](blueprints/02-aws-ec2/scripts/cloud-init.yaml)

---

### 03 · HA Kubernetes

**File:** [`blueprints/04-ha-kubernetes/README.md`](blueprints/04-ha-kubernetes/README.md)

> 📬 **Self-service docs not yet published.** This deployment is fully supported today — contact your AIdome account team.

Highly-available, multi-replica deployment on Kubernetes (EKS / GKE / AKS).
Includes Terraform for cluster infrastructure and Helm charts for the AIdome application
layer. Suitable for production workloads that require horizontal scale and zero-downtime
upgrades.

---

### 04 · Air-Gapped

**File:** [`blueprints/05-air-gapped/README.md`](blueprints/05-air-gapped/README.md)

> 📬 **Self-service docs not yet published.** This deployment is fully supported today — contact [support@aidome.co](mailto:support@aidome.co) to discuss requirements.

Deploy AIdome in a fully isolated, internet-free environment using Ansible.
Designed for regulated industries (defense, finance, healthcare) and on-premises
private-cloud setups where outbound internet access is not permitted. Requires
pre-staged artifacts (container images, packages) delivered by the AIdome team.

---

## 📚 Cross-Cutting Documentation

| Document | Description |
|----------|-------------|
| [Choosing a Blueprint](docs/choosing-a-blueprint.md) | Decision guide: which blueprint fits your needs |
| [Architecture Principles](docs/architecture-principles.md) | Design decisions shared across all blueprints |
| [Security Guidelines](docs/security-guidelines.md) | Security best practices and hardening checklist |

---

## 🔧 Shared Resources

| Path | Description |
|------|-------------|
| [`shared/terraform-modules/`](shared/terraform-modules/) | Reusable Terraform modules shared by AWS blueprints |
| [`shared/scripts/`](shared/scripts/) | Utility scripts (health-checks, migrations, etc.) |
| [`assets/diagrams/`](assets/diagrams/) | Source files for architecture diagrams |

---

## 🤖 AI-Assisted Contribution

This repository is configured for **GitHub Copilot**, **OpenAI Codex / Codex CLI**, and **Claude Code**. The canonical guide for all three is [`AGENTS.md`](AGENTS.md), wired in via:

- [`CLAUDE.md`](CLAUDE.md) — Claude Code entry point
- [`.github/copilot-instructions.md`](.github/copilot-instructions.md) — GitHub Copilot entry point
- `AGENTS.md` itself — Codex / Cursor / Aider convention ([agents.md spec](https://agents.md))

Path-scoped rules live in [`.github/instructions/`](.github/instructions/) (Terraform, Ansible, Kubernetes, CloudFormation, shell, security, …) and are applied automatically by Copilot's `applyTo` front matter. Reusable prompts are in [`.github/prompts/`](.github/prompts/). The [planning-with-files skill](skills/planning-with-files/) is available for multi-step tasks.

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening pull requests.

---

## 📄 License

This project is licensed under the terms in [LICENSE](LICENSE).
