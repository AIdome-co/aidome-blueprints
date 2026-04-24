# Blueprint 01: AWS EC2 – Single-Node Prerequisites — Single Node

> **Scope — Infrastructure Prerequisites Only**
> This blueprint sets up the EC2 server environment: OS hardening, Docker Engine, firewall rules,
> AWS SSM Agent, and the `aidome-ops` operator account. The AIdome product installer (`aidome.sh`),

> Application configuration, `.env` files, and container images are delivered separately by the
> AIdome team.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tested Platforms](#tested-platforms)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
  - [Option A — Terraform](#option-a--terraform)
  - [Option B — CloudFormation](#option-b--cloudformation)
- [Shared Cloud-Init Scripts](#shared-cloud-init-scripts)
- [Security & Hardening](#security--hardening)
- [Verify the Installation](#verify-the-installation)
- [Troubleshooting](#troubleshooting)
- [Rollback](#rollback)
- [Repository Structure](#repository-structure)
- [Further Reading](#further-reading)

---

## Overview

Blueprint 01 deploys a production-ready, single-node EC2 instance for AIdome customer onboarding.
All security hardening and software installation happens automatically at first boot via
**cloud-init**.

You have two equally supported deployment paths. **Both use the same cloud-init scripts** in
`scripts/`:

| Deployment method | Best when… | Directory |
|---|---|---|
| **Option A — Terraform** | You need repeatable, state-tracked deployments | `terraform/` |
| **Option B — CloudFormation** | You prefer AWS-native tooling with no extra local dependencies | `cloudformation/` |

---

## Architecture

```
  Customer / Operator
         │
         │  SSH (port 22) or SSM Session Manager (recommended)
         ▼
  ┌─────────────────────────────────────────────────────┐
  │                    AWS VPC                          │
  │                                                     │
  │   ┌─────────────────────────────────────────────┐  │
  │   │            Private Subnet                   │  │
  │   │                                             │  │
  │   │   ┌───────────────────────────────────┐    │  │
  │   │   │          EC2 Instance             │    │  │
  │   │   │  (no public IP; Ubuntu 24.04 LTS  │    │  │
  │   │   │   recommended)                    │    │  │
  │   │   │                                   │    │  │
  │   │   │  cloud-init on first boot:        │    │  │
  │   │   │  ├─ SSH hardening (port 22)       │    │  │
  │   │   │  ├─ iptables firewall             │    │  │
  │   │   │  ├─ fail2ban                      │    │  │
  │   │   │  ├─ Docker Engine                 │    │  │
  │   │   │  ├─ AWS SSM Agent                 │    │  │
  │   │   │  └─ Dedicated operator user       │    │  │
  │   │   └───────────────────────────────────┘    │  │
  │   │           │                                │  │
  │   │   ┌───────┴──────────┐                     │  │
  │   │   │  Security Group  │                     │  │
  │   │   │  - egress: all   │                     │  │
  │   │   │  - ingress: 22   │                     │  │
  │   │   │    (optional)    │                     │  │
  │   │   └──────────────────┘                     │  │
  │   └─────────────────────────────────────────────┘  │
  │                                                     │
  │   ┌─────────────────────────────────────────────┐  │
  │   │ NAT Gateway / VPC Endpoints (existing infra)│  │
  │   │ Required for: apt/yum, Docker Hub, SSM      │  │
  │   └─────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────┘
         │
         │  outbound (HTTPS/443) for package installs
         ▼
    Internet / AWS Services
```

---

## Tested Platforms

Both cloud-init scripts are tested and supported on the following operating systems:

| OS | Version | Script | Docker repository |
|---|---|---|---|
| **Ubuntu** | 24.04 LTS (Noble Numbat) | `cloud-init-deb.yaml` | `download.docker.com/linux/ubuntu` |
| **Debian** | 12 (Bookworm) | `cloud-init-deb.yaml` | `download.docker.com/linux/debian` |
| **RHEL** | 9 | `cloud-init-rhel.yaml` | `download.docker.com/linux/rhel` |
| **AlmaLinux** | 9 | `cloud-init-rhel.yaml` | `download.docker.com/linux/centos` ① |

> ① AlmaLinux 9 uses the Docker CentOS repository.
> Docker does not publish an AlmaLinux-specific repo, but the CentOS 9 Stream packages are fully compatible with AlmaLinux 9.

---

## Prerequisites

Before you deploy, ensure you have:

- An **existing VPC** with a private subnet that has internet access (NAT Gateway or VPC endpoints for SSM)
- An **EC2 Key Pair** in the target region (you supply the name; keep the private key secure)
- An **IAM instance profile** with at minimum `AmazonSSMManagedInstanceCore`
- **AWS CLI v2** configured with credentials for the target account

| Method | Additional requirement |
|---|---|
| **Terraform** | Terraform `>= 1.5` installed locally |
| **CloudFormation** | `cfn-lint` is optional but recommended for pre-deploy validation |

---

## Quick Start

Both options below launch the same hardened, cloud-init-provisioned instance.

### Option A — Terraform

```bash
# 1. Navigate to the Terraform directory
cd blueprints/01-aws-ec2/terraform

# 2. Copy the example vars file and fill in your values
cp terraform.tfvars.example terraform.tfvars
#    Required vars: vpc_id, subnet_id, key_name, ami_id, os_family

# 3. Initialise providers
terraform init

# 4. Preview what will be created
terraform plan -var-file=terraform.tfvars

# 5. Deploy
terraform apply -var-file=terraform.tfvars

# 6. Get the instance ID
terraform output instance_id
```

### Option B — CloudFormation

```bash
# 1. (Recommended) Validate the template
cfn-lint blueprints/01-aws-ec2/cloudformation/main.yaml

# 2. Deploy the stack
aws cloudformation deploy \
  --template-file blueprints/01-aws-ec2/cloudformation/main.yaml \
  --stack-name aidome-ec2 \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    VpcId=vpc-0abc1234 \
    SubnetId=subnet-0def5678 \
    KeyName=my-ec2-keypair \
    InstanceType=t3.large \
    AmiId=ami-0abcdef1234567890 \
    OsFamily=deb

# 3. Check the stack outputs
aws cloudformation describe-stacks \
  --stack-name aidome-ec2 \
  --query "Stacks[0].Outputs"
```

**`OsFamily` values:** use `deb` for Ubuntu or Debian; use `rhel` for RHEL or AlmaLinux.

> **Finding the right AMI ID** — use the AWS Console (EC2 → AMI Catalog) or the CLI:
>
> ```bash
> # Ubuntu 24.04 LTS in us-east-1
> aws ec2 describe-images \
>   --region us-east-1 \
>   --owners 099720109477 \
>   --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
>   --query "sort_by(Images, &CreationDate)[-1].ImageId" \
>   --output text
> ```

---

## Shared Cloud-Init Scripts

Both deployment options pass a cloud-init script to the EC2 instance's `UserData` at launch.
There are exactly **two scripts** — one per OS family:

```
scripts/
├── cloud-init-deb.yaml    # Ubuntu 24.04, Debian 12
└── cloud-init-rhel.yaml   # RHEL 9, AlmaLinux 9
```

**How each method picks the right script:**

- **Terraform** — the `os_family` variable (`"deb"` or `"rhel"`) controls which script file is
  passed as `user_data`.
- **CloudFormation** — the `OsFamily` parameter (`"deb"` or `"rhel"`) controls which script is
  embedded in `UserData`.

**What cloud-init does on first boot (both scripts):**

1. Applies all pending OS security updates
2. Installs **Docker CE**, `docker-compose-plugin`, `jq`, `unzip`, and **AWS CLI v2** (with GPG
   signature verification)
3. Installs and enables the **AWS SSM Agent**
4. Creates the **`aidome-ops`** system user and adds it to the `docker` group
5. Configures SSH hardening (`PermitRootLogin no`, `AllowUsers aidome-ops`, `LogLevel VERBOSE`)
6. Sets `kernel.randomize_va_space=2` (ASLR — CIS 1.5.2)
7. Applies **iptables** / **firewalld** rules, including the `DOCKER-USER` chain
8. Writes `/etc/audit/rules.d/99-aidome-cis.rules` and loads it with `augenrules --load`

---

## Security & Hardening

Both scripts apply CIS Benchmark Level 1 controls at first boot:

| CIS Control | Reference | Detail |
|---|---|---|
| Privileged command auditing | 4.1.2 | `sudo`, `su` |
| Kernel module auditing | 4.1.3 | `insmod`, `rmmod`, `modprobe` |
| File deletion auditing | 4.1.4 | `unlink`, `rename`, etc. |
| Cron change auditing | 4.1.5 | cron / crontab modifications |
| sudo configuration auditing | 4.1.6 | `/etc/sudoers` changes |
| User/group change auditing | 4.1.7 | passwd, shadow, group, gshadow |
| Login/logout auditing | 4.1.11 | `lastlog`, `faillog`, `tallylog` |
| Setuid/setgid syscall auditing | 4.1.15 | privileged system calls |
| Session initiation auditing | 4.1.17 | `utmp`, `btmp`, `wtmp` |
| `audispd-plugins` installed | 4.1.x | audit dispatcher plugins |
| ASLR | 1.5.2 | `kernel.randomize_va_space=2` |
| SSH root login disabled | 5.2.8 | `PermitRootLogin no` |
| SSH restricted users | 5.2.17 | `AllowUsers aidome-ops` |
| SSH verbose logging | 5.2.5 | `LogLevel VERBOSE` |

---

## Verify the Installation

After the instance is running, connect and run these checks:

```bash
# Connect via SSM Session Manager (no open inbound port 22 required)
aws ssm start-session --target <instance-id>

# On the instance:
sudo systemctl status docker
sudo systemctl status amazon-ssm-agent
sudo systemctl status auditd

id aidome-ops                        # uid, gid, groups — should include 'docker'
sudo docker run --rm hello-world     # container smoke test
sudo auditctl -l | grep aidome       # confirm CIS audit rules are loaded
```

---

## Troubleshooting

### cloud-init did not complete

```bash
sudo cat /var/log/cloud-init-output.log
sudo cloud-init status --long
```

### Docker containers cannot reach the internet

The `DOCKER-USER` iptables chain (Debian/Ubuntu) and firewalld rules (RHEL/AlmaLinux) restrict
container egress to RFC 1918 by default. To allow containers to reach a specific public IP:

```bash
# Debian/Ubuntu
sudo iptables -I DOCKER-USER -d <public-ip>/32 -j ACCEPT
sudo netfilter-persistent save

# RHEL/AlmaLinux
sudo firewall-cmd --permanent \
  --add-rich-rule='rule destination address="<public-ip>/32" accept'
sudo firewall-cmd --reload
```

### SSM Agent not registering

Verify the subnet has connectivity to the SSM VPC endpoints (`ssm`, `ssmmessages`, `ec2messages`)
or a NAT Gateway. The security group must allow **outbound TCP 443**.

### SSH: Permission denied

SSH is restricted to `AllowUsers aidome-ops`. Connect as `aidome-ops` with the key pair you
specified at deploy time.

---

## Getting the AIdome Installer

This repository covers **server prerequisites only**. The `aidome.sh` product installer is owned and distributed by AIdome — it is **not** part of this repository.

Once the server environment is provisioned and passes the readiness check, your technical team should:

1. Contact AIdome to request the `aidome.sh` installer.
2. Follow the AIdome onboarding instructions provided by the AIdome team.
3. Run the installer on the prepared server to complete the product deployment.

> **Note:** Do not attempt to self-source or substitute the `aidome.sh` script. The AIdome team will provide the correct, signed version for your environment.

## Rollback

### Terraform

```bash
cd blueprints/01-aws-ec2/terraform

terraform plan -destroy -var-file=terraform.tfvars   # preview
terraform destroy -var-file=terraform.tfvars          # execute
```

### CloudFormation

```bash
aws cloudformation delete-stack --stack-name aidome-ec2
aws cloudformation wait stack-delete-complete --stack-name aidome-ec2
```

> ⚠️ Instance termination is irreversible.
> Create an AMI snapshot first if you need to preserve the configured state.

---

## Repository Structure

```
blueprints/01-aws-ec2/
├── cloudformation/
│   └── main.yaml              # CloudFormation template (EC2, SG, IAM)
├── terraform/
│   ├── main.tf                # EC2 instance, SG, IAM
│   ├── variables.tf           # Input variables with descriptions and defaults
│   ├── outputs.tf             # instance_id, private_ip, …
│   └── terraform.tfvars.example
└── scripts/
    ├── cloud-init-deb.yaml    # First-boot: Ubuntu / Debian
    └── cloud-init-rhel.yaml   # First-boot: RHEL / AlmaLinux
```

---

## Further Reading

- [Architecture Principles](../../docs/architecture-principles.md)
- [Security Guidelines](../../docs/security-guidelines.md)
- [AWS SSM Agent installation](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-install-ssm-agent.html)
- [Docker CE — Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Docker CE — RHEL](https://docs.docker.com/engine/install/rhel/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)

---
