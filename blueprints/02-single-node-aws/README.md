# 02 · Single-Node AWS — AIdome EC2 Blueprint

> Provision a single EC2 instance on AWS and prepare the OS for AIdome
> product installation using **Terraform** and **cloud-init**.

---

## Overview

This blueprint is a **two-phase** process:

| Phase | What | Tool |
|-------|------|------|
| **1 — Provision & Prep** | Create EC2 instance, VPC, security group; configure OS (packages, users, Docker, disk, sysctl) | Terraform + cloud-init *(this blueprint)* |
| **2 — Product Install** | Install AIdome on the prepared machine | SSH / Ansible / your install tooling |

Phase 1 gets the machine ready. Phase 2 installs the product on top. This
blueprint covers **Phase 1 only**.

---

## Architecture

![Architecture](architecture.png)

**Resources created:**

- VPC with a public subnet, internet gateway, and route table
- Security group (SSH restricted by CIDR, HTTPS open)
- IAM role + instance profile for the EC2 instance
- EC2 instance (Ubuntu 22.04 LTS) with cloud-init OS preparation
- Optional secondary EBS data volume mounted at `/data`

---

## Directory Layout

```
02-single-node-aws/
├── README.md                           ← You are here
├── architecture.png
├── terraform/
│   ├── main.tf                         ← EC2, VPC, security group, EBS, IAM
│   ├── variables.tf                    ← All configurable inputs
│   ├── outputs.tf                      ← Instance IP, SSH command, etc.
│   ├── versions.tf                     ← Provider & Terraform version pins
│   ├── cloud-init.yaml                 ← OS preparation (packages, Docker, sysctl, …)
│   └── environments/
│       └── dev/
│           ├── terraform.tfvars        ← Dev-sized variable values
│           └── backend.hcl             ← Dev S3 state backend config
└── scripts/
    └── validate-prep.sh                ← Verify the instance is ready
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- AWS credentials configured (`aws configure` or environment variables)
- An existing EC2 key pair in the target region

---

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform/

# Local state (simplest for dev):
terraform init

# — OR — remote S3 state:
# terraform init -backend-config=environments/dev/backend.hcl
```

### 2. Review & apply

```bash
# Preview what will be created
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply
terraform apply -var-file=environments/dev/terraform.tfvars
```

> **Important:** Edit `environments/dev/terraform.tfvars` first to set your
> `ssh_key_name` and `allowed_ssh_cidrs`.

### 3. Validate the instance

Once the instance is running and cloud-init has finished (~2-3 minutes):

```bash
../scripts/validate-prep.sh $(terraform output -raw public_ip) ~/.ssh/your-key.pem
```

### 4. Proceed to product installation

SSH into the prepared machine:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@$(terraform output -raw public_ip)
```

The machine is now ready for AIdome product installation (Phase 2).

---

## What Cloud-Init Prepares

| Category | Details |
|----------|---------|
| **Packages** | `curl`, `gnupg`, `jq`, `unzip`, `htop`, `net-tools`, `fail2ban` |
| **Docker** | Docker CE + Compose plugin, `overlay2` storage driver, log rotation |
| **Users** | `aidome` service account (in `docker` group, passwordless sudo) |
| **Disk** | Secondary EBS volume formatted as ext4 and mounted at `/data` |
| **Sysctl** | `vm.max_map_count=262144`, `vm.swappiness=10`, high `somaxconn` / port range |
| **Limits** | Open file descriptor limit raised to 1,048,576 |
| **Security** | IMDSv2 enforced, EBS encryption enabled, `fail2ban` active |

---

## Configuration Reference

All variables are defined in [`terraform/variables.tf`](terraform/variables.tf).
Key inputs:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `instance_type` | `t3.large` | EC2 instance size |
| `ssh_key_name` | *(required)* | EC2 key pair name |
| `root_volume_size` | `50` | Root EBS volume (GiB) |
| `data_volume_size` | `100` | Data EBS volume (GiB); `0` to skip |
| `allowed_ssh_cidrs` | `[]` | CIDRs allowed SSH access |
| `allowed_https_cidrs` | `["0.0.0.0/0"]` | CIDRs allowed HTTPS access |

---

## Tear Down

```bash
terraform destroy -var-file=environments/dev/terraform.tfvars
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `validate-prep.sh` fails "cloud-init completed" | Wait for cloud-init to finish; check `/var/log/cloud-init-output.log` on the instance |
| SSH connection refused | Verify `allowed_ssh_cidrs` includes your IP |
| Data volume not mounted | Confirm `data_volume_size > 0` and check `lsblk` on the instance |
