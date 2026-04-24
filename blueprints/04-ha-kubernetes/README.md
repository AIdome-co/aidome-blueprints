# Blueprint 04 · HA Kubernetes

> 📬 **Self-service documentation for this blueprint is not yet published here.**
> The deployment is **fully supported and operational today** — contact your AIdome
> account team to get started.

---

## Overview

Blueprint 04 deploys AIdome on a **managed Kubernetes cluster** with high availability,
horizontal scaling, and zero-downtime upgrades. It is the recommended path for production
workloads that need resilience beyond what a single node can offer.

## What it provisions

| Layer | Detail |
|---|---|
| Cluster provisioning | Terraform for EKS (AWS), with GKE (GCP) and AKS (Azure) variants |
| Node groups | Autoscaling worker node groups; dedicated node pool for AIdome workloads |
| Networking | VPC-native CNI; network policies enforced |
| Ingress | NGINX or ALB ingress controller with TLS termination |
| Storage | Persistent volumes backed by cloud-provider CSI drivers (gp3 / pd-ssd / Premium SSD) |
| Application layer | Helm charts for all AIdome services; configurable replicas and resource limits |
| Observability | Prometheus + Grafana integration points; structured log shipping |
| Secret management | Integration with AWS Secrets Manager / GCP Secret Manager / Azure Key Vault |

---

## Target audience

- Production deployments requiring **high availability** (multi-replica control plane and data plane)
- Organizations that already operate Kubernetes clusters or have a Kubernetes-fluent platform team
- Workloads with variable traffic that benefit from **horizontal pod autoscaling**

---

## Product installation

AIdome images are hosted at `images.aidome.co` behind authentication and per-customer
license controls. Deployment is performed with AIdome team involvement — it is not
self-service. Contact your AIdome account team to plan a Kubernetes-based rollout.

