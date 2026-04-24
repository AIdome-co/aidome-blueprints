# Blueprint 03 · Single-Node – AWS Greenfield

> 🚧 **This blueprint is Coming Soon.** For an available AWS deployment path, use
> [Blueprint 02 – AWS EC2 (Bring Your Own VPC)](../02-aws-ec2/README.md).

---

## What this blueprint will do

Blueprint 03 provisions a **complete AWS environment from scratch** using a single
Terraform root module — no pre-existing VPC or networking required. It is the right
choice for customers who are starting fresh on AWS and want AIdome running on a single
node without manually wiring up networking.

Planned infrastructure:

| Resource | Detail |
|---|---|
| VPC | New VPC with public + private subnets across two Availability Zones |
| NAT Gateway | Outbound internet access for the private subnet |
| Route tables | Public and private routing |
| EC2 instance | Hardened Ubuntu 24.04 LTS in the private subnet (same cloud-init as Blueprint 02) |
| Security Group | Least-privilege ingress; SSM Session Manager access preferred over SSH |
| Encrypted EBS | gp3, AES-256 at rest |
| IAM role | Instance profile with SSM and CloudWatch permissions |

---

## Difference from Blueprint 02

| | Blueprint 02 | Blueprint 03 |
|---|---|---|
| VPC / subnets | **You bring existing infra** | **Terraform creates from scratch** |
| NAT Gateway | Pre-existing | Created by this blueprint |
| Target customer | AWS-experienced teams with an existing landing zone | Teams starting fresh on AWS |
| EC2 hardening | Identical | Identical |

---

## Product installation

As with all AIdome blueprints, the AIdome registry (`images.aidome.co`) is
access-controlled. Product installation is performed by the AIdome team using
`aidome.sh` together with customer-specific credentials — it is not self-service.
Contact your AIdome account team to schedule the installation step.

---

## Interim option

Until this blueprint is available, use [Blueprint 02](../02-aws-ec2/README.md) with a
manually created (or existing) VPC and private subnet. Blueprint 02 is fully production
ready today.

