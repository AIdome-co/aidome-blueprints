# aidome-blueprints

> **Production-ready deployment blueprints for the AIdome platform.**  
> Pick the blueprint that matches your scale, cloud posture, and operational maturity—then follow its step-by-step guide.

---

## 📋 Blueprint Comparison

| # | Blueprint | Status | Complexity | Cloud | HA | Use-case |
|---|-----------|--------|-----------|-------|----|----------|
| 01 | [Quickstart – Local](blueprints/01-quickstart-local/README.md) | ✅ Available | ⭐ Beginner | None (laptop) | ❌ | Evaluation / development |
| 02 | [AWS EC2 – Bring Your Own VPC](blueprints/02-aws-ec2/README.md) | ✅ Available | ⭐⭐ Intermediate | AWS | ❌ | Harden and prepare an EC2 instance in your existing VPC for AIdome installation |
| 03 | [Single-Node – AWS Greenfield](blueprints/03-single-node-aws/README.md) | 📬 Docs pending — contact us | ⭐⭐ Intermediate | AWS | ❌ | Full AWS infrastructure from scratch (VPC, subnets, NAT, EC2) — for customers with no existing AWS footprint |
| 04 | [HA Kubernetes](blueprints/04-ha-kubernetes/README.md) | 📬 Docs pending — contact us | ⭐⭐⭐ Advanced | AWS / GCP / Azure | ✅ | Production workloads requiring high availability and horizontal scale |
| 05 | [Air-Gapped](blueprints/05-air-gapped/README.md) | 📬 Docs pending — contact us | ⭐⭐⭐⭐ Expert | On-prem / private cloud | ✅ | Regulated / offline environments with no internet access |

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

### 02 · AWS EC2 – Bring Your Own VPC

**File:** [`blueprints/02-aws-ec2/README.md`](blueprints/02-aws-ec2/README.md)

Provision a hardened, private-subnet EC2 instance inside your **existing** AWS VPC.
Cloud-init bootstraps SSH hardening, iptables, fail2ban, Docker Engine, the AWS SSM Agent,
and a dedicated operator user on first boot. Once the instance is ready, the AIdome team
provides credentials and the `aidome.sh` installer to complete the product installation.

> **Use this blueprint when** your customer or your organisation already has an AWS VPC,
> subnets, and routing in place and just needs a correctly hardened host.

**Key files:**
- [`terraform/`](blueprints/02-aws-ec2/terraform/)
- [`cloudformation/`](blueprints/02-aws-ec2/cloudformation/)
- [`scripts/cloud-init.yaml`](blueprints/02-aws-ec2/scripts/cloud-init.yaml)

---

### 03 · Single-Node – AWS Greenfield

**File:** [`blueprints/03-single-node-aws/README.md`](blueprints/03-single-node-aws/README.md)

> 📬 **Self-service docs not yet published.** This deployment is fully supported today — contact your AIdome account team.

Provisions a complete AWS environment from scratch — VPC, private subnets, route tables,
NAT Gateway, and a hardened EC2 instance — using a single Terraform root module. Designed
for customers with no existing AWS footprint who want AIdome running on a single node
without manual networking setup.

As with Blueprint 02, product installation requires AIdome-provided credentials and the
`aidome.sh` installer; the images registry (`images.aidome.co`) is access-controlled.

---

### 04 · HA Kubernetes

**File:** [`blueprints/04-ha-kubernetes/README.md`](blueprints/04-ha-kubernetes/README.md)

> 📬 **Self-service docs not yet published.** This deployment is fully supported today — contact your AIdome account team.

Highly-available, multi-replica deployment on Kubernetes (EKS / GKE / AKS).
Includes Terraform for cluster infrastructure and Helm charts for the AIdome application
layer. Suitable for production workloads that require horizontal scale and zero-downtime
upgrades.

---

### 05 · Air-Gapped

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
