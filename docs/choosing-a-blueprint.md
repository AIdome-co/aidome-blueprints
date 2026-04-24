# Choosing a Blueprint

This guide helps you pick the right AIdome deployment blueprint for your situation.

---

## Quick Decision Tree

```
Do you need high availability (multiple replicas, zero-downtime upgrades)?
  │
  ├─ Yes ──► Blueprint 03 · HA Kubernetes
  │
  └─ No
       │
       Is the target environment air-gapped (no internet access)?
         │
         ├─ Yes ──► Blueprint 04 · Air-Gapped
         │
         └─ No
              │
              Do you want to evaluate AIdome on your laptop without a cloud account?
                │
                ├─ Yes ──► Blueprint 01 · Quickstart – Local
                │
                └─ No  ──► Blueprint 02 · AWS EC2 – Single Node
                              │
                              ├─ Already have an AWS VPC?
                              │     └─ use create_vpc = false (default)
                              │
                              └─ Starting fresh on AWS?
                                    └─ use create_vpc = true
```

---

## Blueprint Comparison

| | 01 · Local | 02 · AWS EC2 | 03 · HA Kubernetes | 04 · Air-Gapped |
|---|---|---|---|---|
| **Cloud** | None (laptop) | AWS | AWS / GCP / Azure | On-prem / private cloud |
| **High availability** | ❌ | ❌ | ✅ | ✅ |
| **Internet required** | ✅ | ✅ | ✅ | ❌ |
| **Complexity** | ⭐ Beginner | ⭐⭐ Intermediate | ⭐⭐⭐ Advanced | ⭐⭐⭐⭐ Expert |
| **Tooling** | Docker Compose | Terraform / CloudFormation | Terraform + Helm | Ansible |
| **Self-service docs** | ✅ | ✅ | 📬 Contact us | 📬 Contact us |

---

## Blueprint 02 · AWS EC2 – Single Node: Bring Your Own VPC vs Greenfield

Blueprint 02 serves both customers who already have AWS infrastructure and those starting from scratch.
The behaviour is controlled by the `create_vpc` Terraform variable.

### `create_vpc = false` (default) — Bring Your Own VPC

Use this when:
- Your organisation already has an AWS VPC, private subnets, and a NAT Gateway (or VPC endpoints for SSM).
- You want Terraform to touch only the EC2 instance and its security group — nothing else.

What Terraform creates: EC2 instance, security group, EBS volume.

### `create_vpc = true` — Greenfield

Use this when:
- You are deploying into a **fresh AWS account** with no existing VPC.
- You want a single `terraform apply` to build the entire environment end-to-end.

What Terraform creates: VPC, public subnet, private subnet, Internet Gateway, Elastic IP,
NAT Gateway, route tables — **plus** the EC2 instance and security group.

The networking resources are provided by the reusable
[`shared/terraform-modules/networking`](../shared/terraform-modules/networking/) module,
which can also be consumed independently by future blueprints.

#### CIDR defaults (all overridable via variables)

| Variable | Default |
|---|---|
| `vpc_cidr` | `10.0.0.0/16` |
| `public_subnet_cidr` | `10.0.0.0/24` |
| `private_subnet_cidr` | `10.0.1.0/24` |
| `availability_zone` | First available AZ in the configured region |

---

## Still unsure?

Contact your AIdome account team — they can recommend the right blueprint based on your
infrastructure, compliance requirements, and scale.
