# Blueprint 03 · Single-Node – AWS Greenfield

> 📬 **Self-service documentation for this blueprint is not yet published here.**
> The deployment is **fully supported and operational today** — contact your AIdome
> account team to get started.

---

## Overview

Blueprint 03 provisions a **complete AWS environment from scratch** using a single
Terraform root module. Unlike [Blueprint 02](../02-aws-ec2/README.md), no pre-existing
VPC or networking is required — everything is created and managed by this blueprint.

It is the right choice for customers who are starting fresh on AWS and want AIdome
running on a single node without manually wiring up networking.

## What it provisions

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

## How it differs from Blueprint 02

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

