# Choosing a Blueprint

This guide helps you pick the right AIdome deployment blueprint for your situation.

---

## Quick Decision Tree

```
Do you need high availability (multiple replicas, zero-downtime upgrades)?
  │
  ├─ Yes ──► Blueprint 02 · HA Kubernetes
  │
  └─ No
       │
        Is the target environment air-gapped (no internet access)?
          │
          ├─ Yes ──► Blueprint 03 · Air-Gapped
          │
          └─ No
               │
               Is the target platform VMware vSphere?
                 │
                 ├─ Yes ──► Blueprint 04 · VMware vSphere – Single Node
                 │            (requires an existing vCenter, template, and port group)
                 │
                 └─ No  ──► Blueprint 01 · AWS EC2 – Single Node
                               (requires an existing AWS VPC + private subnet)
```

---

## Blueprint Comparison

| | 01 · AWS EC2 | 02 · HA Kubernetes | 03 · Air-Gapped | 04 · VMware vSphere |
|---|---|---|---|---|
| **Cloud** | AWS | AWS / GCP / Azure | On-prem / private cloud | On-prem / VMware |
| **High availability** | ❌ | ✅ | ✅ | ❌ |
| **Internet required** | ✅ | ✅ | ❌ | ✅ |
| **Complexity** | ⭐⭐ Intermediate | ⭐⭐⭐ Advanced | ⭐⭐⭐⭐ Expert | ⭐⭐ Intermediate |
| **Tooling** | Terraform / CloudFormation | Terraform + Helm | Ansible | Terraform + cloud-init |
| **Self-service docs** | ✅ | 📬 Contact us | 📬 Contact us | ✅ |

---

## Still unsure?

Contact your AIdome account team — they can recommend the right blueprint based on your
infrastructure, compliance requirements, and scale.
