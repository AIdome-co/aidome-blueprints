# Blueprint 04 · HA Kubernetes

> 🚧 **This blueprint is Coming Soon.** For an available AWS deployment path, use
> [Blueprint 02 – AWS EC2 (Bring Your Own VPC)](../02-aws-ec2/README.md).

---

## What this blueprint will do

Blueprint 04 deploys AIdome on a **managed Kubernetes cluster** with high availability,
horizontal scaling, and zero-downtime upgrades. It is the recommended path for production
workloads that need resilience beyond what a single node can offer.

Planned scope:

| Layer | Detail |
|---|---|
| Cluster provisioning | Terraform for EKS (AWS), with GKE (GCP) and AKS (Azure) variants planned |
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
- Organisations that already operate Kubernetes clusters or have a Kubernetes-fluent platform team
- Workloads with variable traffic that benefit from **horizontal pod autoscaling**

---

## Product installation

AIdome images are hosted at `images.aidome.co` behind authentication and per-customer
licence controls. Deployment is performed with AIdome team involvement — it is not
self-service. Contact your AIdome account team to plan a Kubernetes-based rollout.

---

## Interim option

Until this blueprint is available, use [Blueprint 02](../02-aws-ec2/README.md) for a
single-node AWS deployment that is production-ready today. Kubernetes migration paths
will be documented as part of this blueprint.

