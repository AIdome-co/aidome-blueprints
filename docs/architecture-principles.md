# Architecture Principles

This document records the cross-cutting design decisions that apply to **every** blueprint in `aidome-blueprints`. Individual blueprints may add narrower constraints on top of these principles, but they must never contradict them. New blueprints must be reviewed against this document before merge.

Overlapping areas are split across two companion documents to avoid duplication:

- **This file** — architecture-level principles (topology, identity model, compute model, how blueprints are structured)
- [`security-guidelines.md`](security-guidelines.md) — controls and scanning requirements (secrets, network posture, supply chain, CI tooling)
- [`choosing-a-blueprint.md`](choosing-a-blueprint.md) — blueprint selection guide

---

## Table of Contents

1. [Scope of This Repository](#1-scope-of-this-repository)
2. [Guiding Philosophy](#2-guiding-philosophy)
3. [Blueprint Taxonomy](#3-blueprint-taxonomy)
4. [Networking](#4-networking)
5. [Identity and Access Management](#5-identity-and-access-management)
6. [Compute and OS Hardening](#6-compute-and-os-hardening)
7. [Data Protection at Rest and in Transit](#7-data-protection-at-rest-and-in-transit)
8. [Container Runtime](#8-container-runtime)
9. [Version Pinning and Idempotency](#9-version-pinning-and-idempotency)
10. [Observability](#10-observability)
11. [Rollback and Recovery](#11-rollback-and-recovery)
12. [Decision Log](#12-decision-log)

---

## 1. Scope of This Repository

`aidome-blueprints` provisions the **server environment** only — not the AIdome application itself.

| In scope | Out of scope |
|---|---|
| OS provisioning and hardening | `aidome.sh` product installer |
| Docker Engine installation | `docker-compose.yml` application stack |
| Firewall rules and security group configuration | `.env` application configuration |
| AWS agents (SSM, CloudWatch) | Container images |
| Operator user and SSH access controls | License management |
| Kubernetes cluster infrastructure (Blueprint 02) | Application-layer Helm values |

Once a server passes the prerequisites checklist in its blueprint README, the AIdome team provides the installer and completes the product installation. This boundary is deliberate: it lets customers audit infrastructure changes independently of application updates.

---

## 2. Guiding Philosophy

### 2.1 Blueprints Are Customer-Facing Contracts

Blueprints are not internal tooling — they are the artefacts customers review, approve, and run in their own accounts. Every file should be readable and auditable by a security team that did not write it. Favour explicit, well-commented configuration over clever abstractions.

### 2.2 Security Is Enabled by Default

Security controls are on by default. Disabling any control requires an explicit variable and a comment explaining the accepted risk. A customer who deploys a blueprint without reading the documentation should end up in a reasonably secure state.

### 2.3 Fail Closed

When a provisioning step fails, the system must remain in a secure state. A partially provisioned node with a missing firewall rule is worse than a node that fails to provision at all. Cloud-init steps are written so that re-running after a failure produces a correct final state.

### 2.4 Least Surprise, Not Least Code

A longer, more explicit blueprint that a customer can follow line-by-line is preferable to a terse one that requires knowledge of undocumented conventions. Document the *why*, not just the *what*.

---

## 3. Blueprint Taxonomy

| # | Blueprint | Status | Primary tooling | Purpose |
|---|---|---|---|---|
| 01 | AWS EC2 – Single Node | ✅ Available | Terraform, CloudFormation, cloud-init | Provision and harden a single private-subnet EC2 instance |
| 02 | HA Kubernetes | 📬 Contact AIdome | Terraform + Helm | Production multi-node cluster with high availability |
| 03 | Air-Gapped | 📬 Contact AIdome | Ansible | Fully offline deployment for regulated environments |

Use [`docs/choosing-a-blueprint.md`](choosing-a-blueprint.md) to select the right option for your situation.

Blueprint 01 is the only self-service blueprint with published documentation. Blueprints 02 and 03 are fully supported by the AIdome team but their infrastructure code is not yet self-service; contact your AIdome account team to get started.

---

## 4. Networking

### 4.1 Private-by-Default

All compute resources are deployed into **private subnets** with no public IP address (`associate_public_ip_address = false`). Inbound traffic reaches nodes only through customer-managed NAT Gateways, VPC endpoints, or load balancers.

### 4.2 Bring Your Own VPC (BYOV)

Blueprint 01 requires `vpc_id` and `private_subnet_id` as explicit Terraform variables. It does not create a VPC or subnet. This keeps the networking perimeter under the customer's control and avoids imposing CIDR opinions.

Blueprint 02 follows the same BYOV model for cluster subnets.

### 4.3 Security Groups Follow Least Privilege

The Blueprint 01 security group:

- Allows **all egress** (required for package installs, Docker Hub, AWS service endpoints).
- Allows **SSH ingress on port 22** only when `var.allowed_ssh_cidr` is explicitly set; by default no inbound rules are created.
- Names include the blueprint context (`${name_prefix}-private-sg`) for auditability.

Never widen a security group to `0.0.0.0/0` on an inbound rule without explicit justification in the blueprint README.

### 4.4 Host Firewall as a Second Layer

Blueprint 01 configures `iptables` (Debian/Ubuntu) and `firewalld` (RHEL/AlmaLinux) in addition to the AWS security group, providing defence in depth.

On Debian-family nodes, the `DOCKER-USER` iptables chain restricts container egress to RFC 1918 private address ranges by default. Containers trying to reach public addresses are dropped unless the customer explicitly adds an exception:

```bash
# Allow a specific public IP through the DOCKER-USER chain
sudo iptables -I DOCKER-USER -d <public-ip>/32 -j ACCEPT
sudo netfilter-persistent save
```

This prevents compromised containers from calling back to arbitrary internet endpoints, while still allowing access to NAT-reachable AWS services.

---

## 5. Identity and Access Management

### 5.1 IAM Roles, Not Access Keys

Compute resources authenticate to AWS services using **IAM instance profiles**. Long-lived AWS access keys are never generated, stored, or used by any blueprint. The IAM instance profile name is supplied by the customer via `var.iam_instance_profile_name`; blueprints do not create the IAM role.

At minimum, the instance profile must grant `AmazonSSMManagedInstanceCore` so that SSM Session Manager can be used for keyless shell access. `CloudWatchAgentServerPolicy` is required for the CloudWatch Agent log shipping configured by cloud-init.

### 5.2 IMDSv2 Enforced

Blueprint 01 enforces IMDSv2 on every instance:

```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"          # rejects IMDSv1 requests
  http_put_response_hop_limit = var.metadata_hop_limit  # default: 1
}
```

The hop limit defaults to `1`, preventing container workloads from reaching the instance metadata service unless the limit is deliberately raised.

### 5.3 Operator User (`aidome-ops`)

A non-root OS user (`aidome-ops`) is created by cloud-init on all EC2 nodes:

```yaml
- name: aidome-ops
  groups: [sudo, docker, adm]
  shell: /bin/bash
  sudo: ALL=(ALL) NOPASSWD:ALL
  lock_passwd: true
```

- Password login is disabled (`lock_passwd: true`); authentication is by SSH key only.
- The user is added to the `docker` group, eliminating the need for `sudo docker` in normal operations.
- `sudo` rights are unrestricted (`NOPASSWD:ALL`) to enable full administrative access for the AIdome installer; customers may tighten this after installation.

SSH is restricted to this user via `AllowUsers aidome-ops` in sshd_config (see §6).

### 5.4 Root Login Disabled

SSH root login is disabled (`PermitRootLogin no`) on all nodes.

---

## 6. Compute and OS Hardening

### 6.1 Cloud-Init — What Runs at First Boot

Both cloud-init scripts (`cloud-init-deb.yaml` for Debian/Ubuntu, `cloud-init-rhel.yaml` for RHEL/AlmaLinux) perform the same logical steps at first boot:

1. Apply all pending OS security updates
2. Install Docker CE, `docker-compose-plugin`, `jq`, `unzip`, and AWS CLI v2 (with GPG signature verification)
3. Install and enable the AWS SSM Agent
4. Install and enable the CloudWatch Agent
5. Create the `aidome-ops` operator user
6. Apply SSH hardening
7. Apply sysctl kernel hardening
8. Configure host firewall (`iptables` or `firewalld`)
9. Install and start `fail2ban` (SSH brute-force protection)
10. Enable `unattended-upgrades` (Debian) / `dnf-automatic` (RHEL) for security-only patches
11. Write and load CIS-aligned auditd rules

### 6.2 SSH Hardening

Applied via `/etc/ssh/sshd_config.d/aidome-hardening.conf`:

| Setting | Value |
|---|---|
| `PermitRootLogin` | `no` |
| `PasswordAuthentication` | `no` |
| `PubkeyAuthentication` | `yes` |
| `MaxAuthTries` | `3` |
| `LoginGraceTime` | `60` |
| `ClientAliveInterval` | `300` |
| `AllowUsers` | `aidome-ops` |
| `LogLevel` | `VERBOSE` |
| `X11Forwarding` | `no` |
| `AllowTcpForwarding` | `no` |
| `Compression` | `no` |

### 6.3 Kernel Hardening

Applied via `/etc/sysctl.d/99-aidome-security.conf`:

| Setting | Value | Purpose |
|---|---|---|
| `kernel.randomize_va_space` | `2` | ASLR — full randomisation (CIS 1.5.2) |
| `kernel.dmesg_restrict` | `1` | Hide kernel ring buffer from unprivileged users |
| `kernel.kptr_restrict` | `2` | Hide kernel pointers in /proc |
| `kernel.yama.ptrace_scope` | `1` | Restrict ptrace to parent processes |
| `fs.suid_dumpable` | `0` | Prevent core dumps from setuid processes |
| `net.ipv4.conf.all.rp_filter` | `1` | Reverse-path filtering (anti-spoofing) |
| `net.ipv4.tcp_syncookies` | `1` | SYN-flood protection |
| `net.ipv4.conf.all.log_martians` | `1` | Log packets with impossible source addresses (CIS 3.3.7) |

### 6.4 CIS Auditd Rules

`/etc/audit/rules.d/99-aidome-cis.rules` is written by cloud-init and loaded with `augenrules --load`:

| CIS Control | Reference | What is audited |
|---|---|---|
| Privileged command auditing | 4.1.2 | `sudo`, `su` |
| Kernel module auditing | 4.1.3 | `insmod`, `rmmod`, `modprobe` |
| File deletion auditing | 4.1.4 | `unlink`, `rename`, and related syscalls |
| Cron change auditing | 4.1.5 | cron/crontab modifications |
| sudo configuration auditing | 4.1.6 | `/etc/sudoers` changes |
| User/group change auditing | 4.1.7 | passwd, shadow, group, gshadow |
| Login/logout auditing | 4.1.11 | `lastlog`, `faillog`, `tallylog` |
| Setuid/setgid syscall auditing | 4.1.15 | Privileged system calls |
| Session initiation auditing | 4.1.17 | `utmp`, `btmp`, `wtmp` |

`audispd-plugins` is installed on both OS families to support audit event forwarding.

---

## 7. Data Protection at Rest and in Transit

### 7.1 EBS Encryption at Rest

Every EBS root volume created by Blueprint 01 uses encryption:

```hcl
root_block_device {
  encrypted  = true
  kms_key_id = var.kms_key_id  # optional: customer-managed CMK; defaults to AWS-managed key (aws/ebs)
}
```

### 7.2 Encryption in Transit

- AWS SSM Agent and CloudWatch Agent traffic is encrypted by the AWS service layer.
- Docker daemon is not exposed over TCP; communication is via the Unix socket (`/var/run/docker.sock`) only.
- SSH uses only public-key authentication over an encrypted channel.

---

## 8. Container Runtime

### 8.1 Docker CE Installed from the Official Repository

Cloud-init installs Docker CE from `download.docker.com` using the official APT or DNF repository. GPG signatures are verified before installation. `docker-compose-plugin` is installed alongside Docker CE.

AlmaLinux 9 and other RHEL-compatible distros use the CentOS Docker repository (`download.docker.com/linux/centos`) since Docker does not publish an AlmaLinux-specific repo; the CentOS 9 Stream packages are fully compatible.

### 8.2 Docker Group Membership

The `aidome-ops` user is added to the `docker` group rather than running containers via `sudo docker`. This avoids embedding root password prompts in operational workflows while still granting the required access.

The Docker daemon runs as `root` (required for iptables/`DOCKER-USER` chain management on Blueprint 01 nodes). Rootless Docker is not used.

---

## 9. Version Pinning and Idempotency

### 9.1 Terraform Version Constraints

Blueprint 01 pins the Terraform CLI and AWS provider versions:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

The `.terraform.lock.hcl` file is committed to the repository and records the exact provider version and checksums in use, ensuring reproducible applies across machines.

### 9.2 Other Tooling

When Blueprints 02 and 03 implement their Helm and Ansible toolchains, they will follow the pinning conventions defined in [`security-guidelines.md §6`](security-guidelines.md) (Helm `Chart.lock`, Ansible `requirements.yml` with exact collection versions, and container image digest pinning).

### 9.3 Cloud-Init Idempotency

Cloud-init steps are written to be re-runnable. Package installations use idempotent package manager commands; file writes use `write_files` which overwrites deterministically. Where a step is not naturally idempotent (e.g., a firewall rule reload), it is gated with `|| true` or an existence check so that re-runs do not fail the entire script.

---

## 10. Observability

### 10.1 CloudWatch Agent

Both cloud-init scripts install the CloudWatch Agent and write a base configuration to `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`. Out of the box it ships:

| Log file | CloudWatch log group |
|---|---|
| `/var/log/cloud-init.log` | `/aidome-ec2/cloud-init` |
| `/var/log/syslog` (Debian) / `/var/log/messages` (RHEL) | `/aidome-ec2/syslog` |
| `/var/log/auth.log` (Debian) / `/var/log/secure` (RHEL) | `/aidome-ec2/auth` |

Metrics (CPU, memory, disk) are published to the `AIDome/EC2` CloudWatch namespace with the `InstanceId` dimension.

The CloudWatch Agent requires `CloudWatchAgentServerPolicy` (or equivalent) on the instance IAM profile.

### 10.2 Health Verification Commands

After cloud-init completes, run these checks before proceeding to the AIdome installer:

```bash
# Connect via SSM Session Manager (no open port 22 needed)
aws ssm start-session --target <instance-id>

# On the instance:
sudo systemctl status docker
sudo systemctl status amazon-ssm-agent
sudo systemctl status auditd
sudo systemctl status fail2ban

id aidome-ops              # should include docker group
sudo docker run --rm hello-world   # container smoke test
sudo auditctl -l | grep aidome     # confirm CIS rules are loaded
sudo iptables -L DOCKER-USER -n    # confirm container egress rules (Debian/Ubuntu)
```

---

## 11. Rollback and Recovery

### 11.1 EC2 Instances Are Immutable

Blueprint 01 treats EC2 instances as immutable. The correct response to a misconfigured or broken instance is to terminate it and re-provision with the corrected cloud-init configuration — not to SSH in and repair state in place.

To roll back a deployment:

```bash
# Terraform
terraform plan -destroy -var-file=terraform.tfvars
terraform destroy -var-file=terraform.tfvars

# CloudFormation
aws cloudformation delete-stack --stack-name aidome-ec2
aws cloudformation wait stack-delete-complete --stack-name aidome-ec2
```

> ⚠️ Instance termination is irreversible. Create an AMI snapshot before any major change if you need to preserve the configured state.

### 11.2 Rollback Approach for Other Blueprints

Blueprint 02 (Kubernetes) will use `helm rollback <release> <revision>` for application-layer changes. Blueprint 03 (Air-Gapped/Ansible) rollback procedures will be documented in the blueprint README when that blueprint is completed.

---

## 12. Decision Log

This section records architectural decisions that are not obvious from the code itself.

| ID | Decision | Rationale |
|---|---|---|
| D-001 | BYOV (Bring Your Own VPC) for all blueprints | Customers own their network perimeter. Imposing CIDR choices would conflict with existing infrastructure and create VPC peering complexity. |
| D-002 | Prerequisites-only scope | Separates infrastructure concerns (this repo) from application lifecycle (AIdome team). Reduces blast radius of blueprint changes; customers can audit infrastructure independently. |
| D-003 | Two OS families (Debian and RHEL) via separate cloud-init scripts | Enterprise customers frequently standardise on RHEL-family; cloud-native customers on Debian-family. A single OS would exclude a significant customer segment. The two scripts implement the same logical controls. |
| D-004 | Host firewall (`iptables`/`firewalld`) in addition to AWS security group | Defence in depth. Security groups can be inadvertently widened during customer VPC changes; the host firewall provides a catch. |
| D-005 | `DOCKER-USER` chain restricts container egress to RFC 1918 by default | Prevents a compromised container from reaching arbitrary internet endpoints. Customers who need outbound access to specific public IPs add explicit allow rules. |
| D-006 | IMDSv2 required with hop-limit 1 | Prevents SSRF attacks from reaching the instance metadata endpoint through containerised workloads. |
| D-007 | `aidome-ops` user with full sudo, not a scoped sudo rule | Unrestricted sudo is required by the AIdome installer. Customers who want to tighten this post-install can replace the sudoers rule once the product is deployed. |
| D-008 | Air-Gapped blueprint uses Ansible, not Terraform | Terraform requires network access to provider APIs at plan/apply time. Ansible with an offline inventory has no such dependency, making it the natural choice for fully isolated environments. |


