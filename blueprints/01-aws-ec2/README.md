# Blueprint 01: AWS EC2 – Single-Node Prerequisites — Single Node

> **Scope — Infrastructure Prerequisites Only**
> This blueprint sets up the EC2 server environment: OS hardening, Docker Engine, firewall rules,
> AWS SSM Agent, and the `aidome-ops` operator account. The AIdome product installer (`aidome.sh`),

> application configuration, `.env` files, and container images are delivered separately by the
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

> ① AlmaLinux 9 uses the Docker CentOS repository. Docker does not publish an AlmaLinux-specific
> repo, but the CentOS 9 Stream packages are fully compatible with AlmaLinux 9.

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

> ⚠️ Instance termination is irreversible. Create an AMI snapshot first if you need to preserve
> the configured state.

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

<!-- NOTE TO REVIEWER: Everything below this separator is the pre-existing README content carried
over from before this rewrite. It uses Windows (CRLF) line endings and could not be removed by
the automated edit tooling. Delete everything from this comment to the end of file before merging. -->

 · AWS EC2

> **Scope — infrastructure prerequisites only.** This blueprint provisions the EC2 server environment via cloud-init: OS hardening, Docker Engine, iptables firewall, AWS SSM Agent, CloudWatch Agent, and a dedicated operator user. The AIdome product installer (`aidome.sh`), application configuration (`.env`), and container images are **not** part of this repository — they are delivered separately by the AIdome team once the infrastructure is ready.

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
  │   │   │  (multi-OS; Ubuntu 24.04 LTS recommended, no public IP) │    │  │
  │   │   │                                   │    │  │
  │   │   │  cloud-init on first boot:        │    │  │
  │   │   │  ├─ SSH hardening (port 22)       │    │  │
  │   │   │  ├─ iptables firewall             │    │  │
  │   │   │  ├─ fail2ban                      │    │  │
  │   │   │  ├─ Docker Engine (APT repo)      │    │  │
  │   │   │  ├─ AWS SSM Agent                 │    │  │
  │   │   │  └─ Dedicated operator user       │    │  │
  │   │   │                                   │    │  │
  │   │   │  After boot:                      │    │  │
  │   │   │  └─ Customer runs aidome.sh ───── │──► AIDome installed
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
  │   │ Required for: apt, Docker Hub, SSM, aidome  │  │
  │   └─────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────┘
         │
         │  outbound (HTTPS/443) for package installs + aidome.sh
         ▼
    Internet / AWS Services
```

---

## What it provisions

| Resource | Detail |
|---|---|
| EC2 instance | No public IP; private subnet only |
| Security group | Optional SSH ingress (port 22) from specified CIDR; all egress open |
| Encrypted gp3 EBS | 30 GiB default; AES-256 at rest |
| IMDSv2 enforced | Hop limit = 1; prevents SSRF credential theft |
| cloud-init bootstrap | See below |

### cloud-init bootstrap installs

| Component | Notes |
|---|---|
| SSH hardening | Port 22 only; root login disabled; password auth off; pre-auth banner (`/etc/issue.net`, CIS 5.2.18) |
| iptables firewall | IPv4 + IPv6; SSH open; HTTPS from RFC1918 only; `DOCKER-USER` chain filters container traffic (RFC1918 only) |
| fail2ban | 5 retries, 1-hour ban, SSH port 22 |
| Docker Engine | Installed via official APT repository + GPG verification |
| AWS SSM Agent | Enables SSM Session Manager (no bastion host required) |
| CloudWatch Agent | System metrics (CPU, mem, disk) + log shipping to CloudWatch Logs |
| Dedicated operator | `aidome-ops` non-root sudo user; Docker group member |
| sysctl hardening | CIS-aligned kernel + network parameters |
| Unattended upgrades | Security patches auto-applied |

---

## Pre-requisites

- Existing VPC with a **private subnet**
  - **NAT Gateway** for outbound HTTPS (apt, Docker Hub, SSM) — _or_ —
  - **VPC Interface Endpoints** (`com.amazonaws.<region>.ssm`, `com.amazonaws.<region>.ssmmessages`, `com.amazonaws.<region>.ec2messages`) for a fully private deployment without a NAT Gateway
- AMI matching the selected `os_type` (see [Supported operating systems](#supported-operating-systems) below for lookup commands)
- **IAM instance profile** with `AmazonSSMManagedInstanceCore` policy — **required for SSM Session Manager access** (strongly recommended over SSH for private-subnet instances; without it, SSM will not work)

---

## Supported operating systems

Set `os_type` (Terraform) or `OsType` (CloudFormation) to select the target OS.
The correct cloud-init script and root block device name are derived automatically.

> **Vendor recommendation:** Ubuntu 24.04 LTS. All other OS types are community-supported.

| `os_type` value | Distribution | Support | Cloud-init script | Root device |
|---|---|:---:|---|---|
| `ubuntu-2404` | Ubuntu 24.04 LTS (Noble) | ✅ Vendor | `cloud-init-deb.yaml` | `/dev/sda1` |
| `ubuntu-2204` | Ubuntu 22.04 LTS (Jammy) | 🟢 Community | `cloud-init-deb.yaml` | `/dev/sda1` |
| `debian-12` | Debian 12 (Bookworm) | 🟢 Community | `cloud-init-deb.yaml` | `/dev/xvda` |
| `centos-9` | CentOS Stream 9 | 🟢 Community | `cloud-init-rhel.yaml` | `/dev/sda1` |
| `rhel-9` | Red Hat Enterprise Linux 9 | 🟡 Conditional | `cloud-init-rhel.yaml` | `/dev/sda1` |
| `rhel-10` | Red Hat Enterprise Linux 10 | 🔴 Experimental | `cloud-init-rhel.yaml` | `/dev/sda1` |
| `almalinux-9` | AlmaLinux 9 (RHEL-compatible) | 🟢 Community | `cloud-init-rhel.yaml` | `/dev/sda1` |
| `oracle-9` | Oracle Linux 9 (RHEL-compatible) | 🟢 Community | `cloud-init-rhel.yaml` | `/dev/sda1` |
| `rocky-9` | Rocky Linux 9 (RHEL-compatible) | 🟢 Community | `cloud-init-rhel.yaml` | `/dev/sda1` |

**Support tiers:** ✅ Vendor = tested and maintained by AIdome · 🟢 Community = expected to work, not regularly tested · 🟡 Conditional = works with caveats (see footnotes) · 🔴 Experimental = known gaps, not production-ready

### Feature heatmap

What each cloud-init script installs and configures, per OS.

**Legend:** 🟢 Full &nbsp; 🟡 Partial / conditional &nbsp; 🔴 Not supported / missing

| OS | OS Hardening<br>(sysctl · SSH · auditd · fail2ban) | Docker Engine<br>+ Compose | CLI Tools<br>(curl · wget · jq · AWS CLI v2) | iptables<br>Firewall | SSM<br>Agent | CloudWatch<br>Agent | Auto-<br>updates | Package<br>Cleanup |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Ubuntu 24.04 LTS | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| Ubuntu 22.04 LTS | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| Debian 12 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| CentOS Stream 9 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| RHEL 9 | 🟡 ² | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| RHEL 10 | 🟡 ² | 🔴 ³ | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| AlmaLinux 9 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| Oracle Linux 9 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |
| Rocky Linux 9 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 ¹ | 🟢 | 🟢 |

> ¹ **CloudWatch Agent** — ships data and logs only when the IAM instance profile has `CloudWatchAgentServerPolicy` attached. Agent is installed and started on all OS types; it silently no-ops without the policy.
>
> ² **fail2ban on RHEL 9 / RHEL 10** requires EPEL. The cloud-init script enables EPEL via `subscription-manager` (CodeReady Builder) and the EPEL release RPM; this step fails silently if the instance has no active RHEL subscription, leaving fail2ban uninstalled. sysctl hardening, SSH hardening, and auditd are unaffected.
>
> ³ **Docker CE on RHEL 10** — Docker Inc. does not yet publish official packages for RHEL 10. The cloud-init Docker install step will fail. Install Podman (pre-installed on RHEL 10) or Docker CE manually using a compatible binary.

### AMI lookup commands

Run these in your target region (`--region <region>`) to find the latest AMI for each OS.
Always use the AMI ID exactly as returned — never use the name pattern as the AMI ID.

```bash
# Ubuntu 24.04 LTS (Noble) — recommended; owner: Canonical
aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# Ubuntu 22.04 LTS (Jammy) — owner: Canonical
aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-jammy-22.04-amd64-server-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# Debian 12 (Bookworm) — owner: Debian official
aws ec2 describe-images --owners 136693071363 \
  --filters 'Name=name,Values=debian-12-amd64-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# CentOS Stream 9 — owner: CentOS official
aws ec2 describe-images --owners 125523088429 \
  --filters 'Name=name,Values=CentOS Stream 9*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# RHEL 9 — owner: Red Hat (309956199498)
aws ec2 describe-images --owners 309956199498 \
  --filters 'Name=name,Values=RHEL-9*GA*' \
            'Name=architecture,Values=x86_64' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# RHEL 10 — owner: Red Hat (309956199498)
aws ec2 describe-images --owners 309956199498 \
  --filters 'Name=name,Values=RHEL-10*GA*' \
            'Name=architecture,Values=x86_64' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# AlmaLinux 9 — owner: AlmaLinux OS Foundation (764336703387)
aws ec2 describe-images --owners 764336703387 \
  --filters 'Name=name,Values=AlmaLinux OS 9*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# Oracle Linux 9 — owner: Oracle (131827586825)
aws ec2 describe-images --owners 131827586825 \
  --filters 'Name=name,Values=OL9*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text

# Rocky Linux 9 — owner: Rocky Linux (792107900699)
aws ec2 describe-images --owners 792107900699 \
  --filters 'Name=name,Values=Rocky-9-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text
```

### OS family differences

| Feature | Debian family (`cloud-init-deb.yaml`) | RHEL family (`cloud-init-rhel.yaml`) |
|---|---|---|
| Package manager | APT | DNF |
| Docker repo | `download.docker.com/linux/{ubuntu\|debian}` | `download.docker.com/linux/{rhel\|centos}` |
| Firewall persistence | `netfilter-persistent` / `iptables-persistent` | `iptables-services`; `firewalld` disabled |
| Auto-updates | `unattended-upgrades` | `dnf-automatic` (security only) |
| SSM Agent | snap (Ubuntu) / apt (Debian) fallback | DNF / RPM from S3 |
| CloudWatch Agent | `.deb` package | `.rpm` package |
| Sudo group | `sudo` | `wheel` |
| Syslog path | `/var/log/syslog`, `/var/log/auth.log` | `/var/log/messages`, `/var/log/secure` |

---

## Usage

### Terraform

```hcl
module "aidome_ec2" {
  source = "./blueprints/01-aws-ec2/terraform"

  vpc_id            = "vpc-xxxxxxxx"
  private_subnet_id = "subnet-xxxxxxxx"
  os_type           = "ubuntu-2404"  # vendor recommended; see README for all supported OS types
  ami_id            = "ami-xxxxxxxx"  # Ubuntu 24.04 LTS (Noble) — must match os_type

  # Recommended: attach an IAM profile with AmazonSSMManagedInstanceCore
  # (add CloudWatchAgentServerPolicy to the same role to enable metrics/log shipping)
  iam_instance_profile_name = "aidome-ssm-profile"

  # Optional: allow SSH from an internal CIDR (SSM Session Manager is preferred)
  allowed_ssh_cidr = "10.0.0.0/8"
  key_name         = "my-key-pair"

  instance_type    = "t3.small"
  root_volume_size = 30

  # Optional: customer-managed KMS key for the EBS root volume
  # kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/mrk-xxxxxxxx"

  tags = {
    Environment = "dev"
    Project     = "aidome"
  }
}
```

A ready-to-edit [`terraform.tfvars.example`](terraform/terraform.tfvars.example) is provided alongside the module. See [`variables.tf`](terraform/variables.tf) for the full list of inputs and [`outputs.tf`](terraform/outputs.tf) for the exposed outputs (`instance_id`, `private_ip`, `security_group_id`).

### CloudFormation

Deploy `cloudformation/ec2-private.yaml` via AWS Console, CLI, or CI/CD:

```bash
aws cloudformation deploy \
  --template-file blueprints/01-aws-ec2/cloudformation/ec2-private.yaml \
  --stack-name aidome-ec2 \
  --parameter-overrides \
      VpcId=vpc-xxxxxxxx \
      PrivateSubnetId=subnet-xxxxxxxx \
      OsType=ubuntu-2404 \
      AmiId=ami-xxxxxxxx \
      IamInstanceProfileName=aidome-ssm-profile \
  --capabilities CAPABILITY_NAMED_IAM
```

Pass cloud-init content via the `CloudInitUserData` parameter (base64-encoded by the template).
Use `scripts/cloud-init-deb.yaml` for Debian-family OS types (`ubuntu-*`, `debian-12`) and
`scripts/cloud-init-rhel.yaml` for RHEL-family types (`centos-9`, `rhel-*`, `almalinux-9`, `oracle-9`, `rocky-9`).

---

## Post-boot: install AIDome

> **Note:** `aidome.sh` and the application container images are **not** part of this repository. This section is provided as context only. The AIdome team will supply the installer URL and credentials once the infrastructure is provisioned.

Once the EC2 instance is up and cloud-init has completed (~5 min):

```bash
# Connect via SSM Session Manager (recommended — no open ports needed)
aws ssm start-session --target <instance-id>

# Or connect via SSH if key_name / AllowedSshCidr was set
ssh -i my-key.pem aidome-ops@<private-ip>

# Confirm cloud-init finished successfully before proceeding
cloud-init status --wait
cat /var/log/cloud-init-output.log | tail -n 20   # optional sanity check

# Install AIDome
curl -fsSL https://your-bucket/aidome.sh | sudo bash
```

For stricter environments, download, inspect, and then run:

```bash
curl -fsSLO https://your-bucket/aidome.sh
less aidome.sh
sudo bash aidome.sh
```

---

## Security notes

- **SSM Session Manager is preferred** over SSH for private-subnet access. No bastion host or open inbound ports needed; access is IAM-controlled and logged to CloudTrail.
- Restrict `allowed_ssh_cidr` / `AllowedSshCidr` to the narrowest practical range.
- **VPC endpoints for SSM**: if the subnet has no NAT Gateway, create VPC Interface Endpoints for `ssm`, `ssmmessages`, and `ec2messages` to allow the SSM Agent to reach AWS APIs without internet access.
- Host iptables accept SSH from any source by default (defense-in-depth; the primary perimeter is the AWS Security Group). For stricter hosts, tighten the `INPUT` SSH rule to match your `allowed_ssh_cidr` after provisioning.
- **CloudWatch Agent** is installed automatically. To activate metrics and log shipping, attach the `CloudWatchAgentServerPolicy` managed policy to the instance profile (alongside `AmazonSSMManagedInstanceCore`).
- **Customer-managed KMS key**: pass `kms_key_id` (Terraform) or `KmsKeyId` (CloudFormation) to encrypt the EBS volume with your own key instead of the default AWS managed key.
- Review and tighten egress rules before production use.
- To enable IP forwarding for future VPN use, uncomment the `ip_forward` lines in `scripts/cloud-init.yaml` under `/etc/sysctl.d/99-aidome-security.conf`.
