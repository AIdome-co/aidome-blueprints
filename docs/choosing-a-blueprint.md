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
                              (requires an existing AWS VPC + private subnet)
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

## Still unsure?

Contact your AIdome account team — they can recommend the right blueprint based on your
infrastructure, compliance requirements, and scale.
