# aidome-blueprints

> **Production-ready deployment blueprints for the AIdome platform.**  
> Pick the blueprint that matches your scale, cloud posture, and operational maturity—then follow its step-by-step guide.

---

## 📋 Blueprint Comparison

| # | Blueprint | Complexity | Cloud | HA | Use-case |
|---|-----------|-----------|-------|----|----------|
| 01 | [Quickstart – Local](blueprints/01-quickstart-local/README.md) | ⭐ Beginner | None (laptop) | ❌ | Evaluation / development |
| 02 | [AWS EC2](blueprints/02-aws-ec2/README.md) | ⭐⭐ Intermediate | AWS | ❌ | Customer EC2 prep for AIDome installation |
| 03 | [Single-Node – AWS](blueprints/03-single-node-aws/README.md) | ⭐⭐ Intermediate | AWS | ❌ | Small teams / PoC |
| 04 | [HA Kubernetes](blueprints/04-ha-kubernetes/README.md) | ⭐⭐⭐ Advanced | AWS / GCP / Azure | ✅ | Production workloads |
| 05 | [Air-Gapped](blueprints/05-air-gapped/README.md) | ⭐⭐⭐⭐ Expert | On-prem / private cloud | ✅ | Regulated / offline environments |

---

## 🗂️ Repository Layout

```
aidome-blueprints/
├── README.md                         ← You are here
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
└── .github/
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

### 02 · AWS EC2

**File:** [`blueprints/02-aws-ec2/README.md`](blueprints/02-aws-ec2/README.md)

Provision a hardened, private-subnet EC2 instance that bootstraps itself via cloud-init  
and is ready for the customer to run `aidome.sh` to install the AIDome product.

**Key files:**
- [`terraform/`](blueprints/02-aws-ec2/terraform/)
- [`cloudformation/`](blueprints/02-aws-ec2/cloudformation/)
- [`scripts/cloud-init.yaml`](blueprints/02-aws-ec2/scripts/cloud-init.yaml)

---

### 03 · Single-Node – AWS

**File:** [`blueprints/03-single-node-aws/README.md`](blueprints/03-single-node-aws/README.md)

Deploy AIdome on a single EC2 instance with Terraform.  
Suitable for small teams and proof-of-concept deployments where HA is not required.

**Key files:**
- [`terraform/`](blueprints/03-single-node-aws/terraform/)
- [`architecture.png`](blueprints/03-single-node-aws/architecture.png)

---

### 04 · HA Kubernetes

**File:** [`blueprints/04-ha-kubernetes/README.md`](blueprints/04-ha-kubernetes/README.md)

Highly-available, multi-replica deployment on Kubernetes (EKS / GKE / AKS).  
Includes Terraform for infrastructure and Helm charts for the AIdome application layer.

**Key files:**
- [`terraform/`](blueprints/04-ha-kubernetes/terraform/)
- [`helm/`](blueprints/04-ha-kubernetes/helm/)
- [`architecture.png`](blueprints/04-ha-kubernetes/architecture.png)

---

### 05 · Air-Gapped

**File:** [`blueprints/05-air-gapped/README.md`](blueprints/05-air-gapped/README.md)

Deploy AIdome in a fully isolated, internet-free environment using Ansible.  
Designed for regulated industries and on-premises private-cloud setups.

**Key files:**
- [`ansible/`](blueprints/05-air-gapped/ansible/)

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

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening pull requests.

---

## 📄 License

This project is licensed under the terms in [LICENSE](LICENSE).
