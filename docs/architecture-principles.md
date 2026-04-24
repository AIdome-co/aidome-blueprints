# Architecture Principles

This document records the cross-cutting design decisions that apply to **every** blueprint in `aidome-blueprints`. Individual blueprints may add narrower constraints on top of these principles, but they must never contradict them. New blueprints must be reviewed against this document before merge.

---

## Table of Contents

1. [Scope of This Repository](#1-scope-of-this-repository)
2. [Guiding Philosophy](#2-guiding-philosophy)
3. [Networking](#3-networking)
4. [Identity and Access Management](#4-identity-and-access-management)
5. [Secrets Management](#5-secrets-management)
6. [Data Protection](#6-data-protection)
7. [OS and Compute Hardening](#7-os-and-compute-hardening)
8. [Container Runtime](#8-container-runtime)
9. [Supply Chain and Version Pinning](#9-supply-chain-and-version-pinning)
10. [Idempotency and Drift Prevention](#10-idempotency-and-drift-prevention)
11. [Observability and Auditability](#11-observability-and-auditability)
12. [Rollback and Recovery](#12-rollback-and-recovery)
13. [Blueprint Taxonomy](#13-blueprint-taxonomy)
14. [Decision Log](#14-decision-log)

---

## 1. Scope of This Repository

`aidome-blueprints` provisions the **server environment** only — not the AIdome application itself.

| In scope | Out of scope |
|---|---|
| OS provisioning and hardening | `aidome.sh` product installer |
| Docker Engine installation and hardening | `docker-compose.yml` application stack |
| Firewall rules and security group configuration | `.env` application configuration |
| AWS agents (SSM, CloudWatch) | Container images |
| Operator user and SSH access controls | License management |
| Kubernetes cluster infrastructure (Blueprint 02) | Application-layer Helm values |

Once a server passes the prerequisites checklist in its blueprint README, the AIdome team provides the installer and completes product installation. The boundary is deliberate: it lets customers audit infrastructure changes independently of application updates.

---

## 2. Guiding Philosophy

### 2.1 Blueprints Are Customer-Facing Contracts

Blueprints are not internal tooling — they are the artefacts customers review, approve, and run in their own accounts. Every file should be readable and auditable by a security team that did not write it. Favour explicit, well-commented configuration over clever abstractions.

### 2.2 Least Surprise, Not Least Code

A longer, more explicit blueprint that a customer can follow line-by-line is preferable to a terse one that requires knowledge of undocumented conventions. Document the *why*, not just the *what*.

### 2.3 Security Is Non-Negotiable

Security controls are enabled by default. Disabling any control requires an explicit variable (`var.enable_*` with `default = false` for additive features, or a `var.disable_*` flag for protective controls) and a comment explaining the risk accepted.

### 2.4 Fail Closed

When a provisioning step fails, the system must remain in a secure state. A partially provisioned node with a missing firewall rule is worse than a node that fails to provision at all. Design idempotent scripts so that re-running them after a failure produces a correct final state.

---

## 3. Networking

### 3.1 Private-by-Default

All compute resources (EC2 instances, Kubernetes nodes) are deployed into **private subnets**. Public IP addresses are not assigned. Inbound traffic reaches nodes only through:

- An AWS Application Load Balancer or Network Load Balancer (for Blueprint 01)
- An AWS-managed or self-managed ingress controller (for Blueprint 02)

Blueprints that require a public subnet (e.g., NAT Gateway, bastion) must place non-compute resources there and justify the decision in the README.

### 3.2 Bring Your Own VPC (BYOV)

Blueprint 01 (`01-aws-ec2`) accepts `vpc_id` and `private_subnet_id` as required Terraform variables. It does **not** create a VPC. This keeps the networking perimeter under the customer's control and avoids imposing CIDR opinions.

Blueprint 02 (`02-ha-kubernetes`) follows the same BYOV model for the control plane and worker node subnets.

If a customer needs a reference VPC, the `shared/terraform-modules/networking/` module provides a ready-made single-AZ VPC with public and private subnets, IGW, NAT Gateway, and route tables. It is opt-in, not mandatory.

### 3.3 Security Groups Follow Least Privilege

Every security group:

- Has a descriptive `name` and `description` that includes the blueprint name and purpose.
- Defines only the ports and protocols required for documented traffic flows.
- Uses the most specific CIDR or source security group available.
- Does not include a `0.0.0.0/0` ingress rule except where explicitly required (e.g., ALB port 443) and documented.

### 3.4 Host Firewall Reinforces the Security Group

Blueprint 01 configures `iptables` in addition to the AWS security group. The host firewall provides defence in depth: if a security group is misconfigured during a customer's VPC change, the host firewall remains as the last line of defence.

The `DOCKER-USER` chain is configured to allow Docker container outbound traffic only to RFC 1918 private ranges and known AIdome endpoints, preventing compromised containers from calling back to arbitrary internet addresses.

### 3.5 IPv6

Blueprints do not enable IPv6 by default. IPv6 support may be added in a future version with the same private-by-default controls applied to both address families.

---

## 4. Identity and Access Management

### 4.1 IAM Roles, Not Keys

Compute resources authenticate to AWS services using **IAM roles attached to instances or node groups**. Long-lived AWS access keys are never generated, stored, or used in blueprints.

Required IAM permissions follow the least-privilege principle. Each blueprint's `iam.tf` (or equivalent CloudFormation resource) documents the purpose of every permission granted.

### 4.2 Instance Profiles for EC2

Blueprint 01 attaches a dedicated instance profile to the EC2 instance with exactly the permissions needed to:

- Register with AWS Systems Manager (SSM).
- Write logs to CloudWatch Logs.
- Pull from ECR repositories designated for AIdome images.

No other permissions are granted. Customers who need additional permissions must attach supplementary policies through their own Terraform or CloudFormation — never by modifying the blueprint's IAM role directly.

### 4.3 Operator User (`aidome-ops`)

A non-root OS user (`aidome-ops`) is created on all EC2 nodes. This user:

- Is the only user allowed to connect via SSH (enforced via `AllowUsers` in `sshd_config`).
- Has `sudo` rights scoped to Docker management commands only (no unrestricted `sudo ALL`).
- Does not have a password set; authentication is by SSH key only.

The `authorized_keys` for `aidome-ops` is injected at cloud-init time from a customer-supplied `var.ops_public_key` variable.

### 4.4 Root Login Disabled

SSH root login is disabled (`PermitRootLogin no`) on all nodes.

### 4.5 Kubernetes RBAC (Blueprint 02)

Kubernetes workloads run under dedicated `ServiceAccount` resources with RBAC roles scoped to the namespace and resource types they require. `ClusterAdmin` bindings are not granted to application workloads.

---

## 5. Secrets Management

### 5.1 No Secrets in Git

The following must **never** be committed to this repository:

- AWS access keys or secret keys
- TLS private keys or certificates
- Database passwords or connection strings
- API tokens or bearer credentials
- `.tfstate` files or `.tfstate.backup` files
- `.tfvars` files containing sensitive values (`.tfvars.example` files with placeholder values are allowed)
- `.env` files

The `.gitignore` at the root enforces these exclusions.

### 5.2 Runtime Secret Sources

| Secret type | Preferred source |
|---|---|
| AWS credentials on EC2 | Instance profile (no key needed) |
| Database passwords | AWS Secrets Manager |
| SSM parameters | AWS Systems Manager Parameter Store (SecureString) |
| Kubernetes Secrets | Sealed Secrets or External Secrets Operator backed by Secrets Manager |
| Ansible vault data | Ansible Vault (key stored in Secrets Manager or SSM) |

### 5.3 Sensitive Terraform Variables

Variables marked `sensitive = true` in Terraform must not appear in plan output or state in plaintext. Use Secrets Manager or SSM data sources to fetch secrets at apply time rather than passing them as `terraform.tfvars` inputs.

---

## 6. Data Protection

### 6.1 Encryption at Rest

| Resource | Requirement |
|---|---|
| EBS root volumes | AES-256 (KMS CMK or AWS-managed key) |
| EBS data volumes | AES-256 (KMS CMK preferred) |
| S3 buckets (state, logs) | SSE-S3 minimum; SSE-KMS preferred |
| EFS mounts (Blueprint 02) | Encryption enabled at creation |

Blueprints include `encrypted = true` on all EBS resources and `server_side_encryption_configuration` blocks on all S3 resources.

### 6.2 Encryption in Transit

- All inter-service communication uses TLS 1.2 or higher.
- SSM Sessions and CloudWatch agent traffic are encrypted by the AWS service.
- Docker daemon is not exposed over TCP; communication is via the Unix socket only.
- Kubernetes API server uses TLS; etcd uses TLS peer and client certificates.

### 6.3 TLS Certificate Sources

- Public-facing load balancers use ACM-managed certificates.
- Internal Kubernetes traffic uses certificates issued by the cluster CA.
- Blueprints do not generate self-signed certificates for production use.

---

## 7. OS and Compute Hardening

### 7.1 CIS Benchmark Alignment

Blueprint 01 targets **CIS Amazon Linux 2 / Ubuntu 22.04 / RHEL 9 Level 1** where applicable. The cloud-init scripts configure:

| Area | Controls applied |
|---|---|
| Kernel hardening | `kernel.randomize_va_space=2` (ASLR), IP forwarding disabled where not needed |
| SSH | `LogLevel VERBOSE`, `PermitRootLogin no`, `PasswordAuthentication no`, `AllowUsers aidome-ops`, `MaxAuthTries 4`, `ClientAliveInterval 300` |
| Auditd | Rules covering CIS 4.1.2–4.1.17: file modification, privilege escalation, network calls, setuid/setgid executables |
| Filesystem | `/tmp` on a separate mount with `noexec,nosuid,nodev`; unnecessary filesystems disabled |
| Packages | Unnecessary services removed; `aide`, `auditd`, `fail2ban` installed |

Variant scripts exist for Debian-family (`cloud-init-deb.yaml`) and RHEL-family (`cloud-init-rhel.yaml`) operating systems. Both implement the same logical controls even where the package names or configuration paths differ.

### 7.2 Unattended Security Updates

Automatic security patching (`unattended-upgrades` on Debian; `dnf-automatic` on RHEL) is enabled with security-only updates. Customers are responsible for scheduling the maintenance window; blueprints set the update type but not the cron schedule.

### 7.3 SSH Key Rotation

The `aidome-ops` SSH public key is injected via cloud-init. Rotation requires re-deployment or an out-of-band key update through SSM Run Command. A key-rotation runbook is included in the Blueprint 01 README.

---

## 8. Container Runtime

### 8.1 Docker CE, Pinned Version

All blueprints that install Docker use **Docker CE** with a pinned version specified in the cloud-init or Ansible variable file. The `:latest` tag is never used for the Docker package itself.

### 8.2 Rootless Docker vs. Root

Docker runs as `root` in Blueprint 01 (required for `iptables` manipulation and `DOCKER-USER` chain management). The `aidome-ops` user is added to the `docker` group rather than using `sudo docker`. The security trade-off is documented in the Blueprint 01 README.

### 8.3 Docker Daemon Hardening

`/etc/docker/daemon.json` sets:

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m", "max-file": "3" },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}
```

`userns-remap` is evaluated per deployment; it is not enabled by default because it requires UID/GID mapping planning that is customer-specific.

### 8.4 Container Image Governance

Container images used by AIdome are **not pulled from public registries at runtime**. They are provided from a customer-specific ECR repository or delivered as tarballs in air-gapped deployments. Blueprints configure the container runtime to pull only from the designated registry endpoint.

---

## 9. Supply Chain and Version Pinning

### 9.1 Terraform

Every Terraform root module specifies:

```hcl
terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Provider and module versions use `~>` (patch-level floating) rather than exact pins to receive security patches automatically while avoiding breaking changes.

### 9.2 Helm Charts (Blueprint 02)

Helm chart versions in `Chart.yaml` are pinned with `version` and `appVersion` exact values. `helm dependency update` is run in CI to produce a locked `Chart.lock` that is committed.

### 9.3 Ansible Collections (Blueprint 03)

`requirements.yml` specifies exact collection versions. The lockfile approach uses `ansible-galaxy collection install --requirements-file requirements.yml` in CI with the output verified before merge.

### 9.4 Container Images

Container image references in Helm `values.yaml` and Docker Compose files always include a SHA256 digest alongside the tag:

```yaml
image:
  repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/aidome
  tag: "1.4.2"
  digest: "sha256:abcdef..."
```

### 9.5 GitHub Actions Workflows

All `uses:` references in workflow files pin to a full 40-character commit SHA, not a tag. Tags are mutable; SHAs are not.

---

## 10. Idempotency and Drift Prevention

### 10.1 Declarative First

Terraform and Helm are the preferred tools because their state models make idempotency structural rather than a coding discipline. Shell scripts and Ansible playbooks are acceptable for bootstrapping steps that Terraform cannot manage (e.g., cloud-init, OS package installation) but must be written to be re-runnable safely.

### 10.2 Ansible Idempotency Rules

- Use module-level idempotency (`ansible.builtin.package`, `ansible.builtin.template`, `ansible.builtin.service`) rather than `shell`/`command`.
- Every `shell` or `command` task must include `creates:` or `removes:` or be gated by a `when:` condition that checks current state.
- `changed_when: false` is appropriate for read-only commands (fact gathering), not for write operations.

### 10.3 Terraform State

Terraform state must be stored in a remote backend (S3 + DynamoDB for locking) — never on a local filesystem or in git. The backend configuration is provided as a separate `backend.hcl` file passed to `terraform init -backend-config=backend.hcl` so that state bucket names (which may contain account IDs) do not appear in committed code.

### 10.4 Configuration Drift Detection

Blueprint 01 installs the AWS SSM Agent, which enables AWS Config rules and Systems Manager State Manager associations for drift detection. Detected drift generates a CloudWatch alarm. Customers are expected to configure their own SNS notifications for these alarms.

---

## 11. Observability and Auditability

### 11.1 Structured Logging

All services write logs to `stdout`/`stderr`. The CloudWatch agent ships logs to a named log group following the convention:

```
/aidome/<blueprint-id>/<instance-id>/<component>
```

Log retention is set to 90 days by default. Customers may change this via the `var.log_retention_days` variable.

### 11.2 Auditd

Blueprint 01 installs and enables `auditd`. The ruleset (`/etc/audit/rules.d/99-aidome-cis.rules`) captures:

- Privileged command execution (setuid/setgid binaries)
- File permission and ownership changes (`chmod`, `chown`)
- Module loading and unloading
- Failed authentication attempts
- Network socket creation by privileged processes

Audit logs are shipped to CloudWatch alongside application logs.

### 11.3 AWS CloudTrail

Blueprints do not create or modify CloudTrail trails — that is a customer account-wide concern. Blueprints do document which AWS API calls they make so customers can verify that their trail captures the expected events.

### 11.4 Health Verification Commands

Every blueprint README includes a "Verify the Installation" section with commands the customer can run to confirm the environment is healthy before running the AIdome installer. Example (Blueprint 01):

```bash
# Confirm Docker is running
sudo systemctl status docker

# Confirm SSM agent is running
sudo systemctl status amazon-ssm-agent

# Confirm firewall rules are loaded
sudo iptables -L DOCKER-USER -n

# Confirm audit daemon is active
sudo auditctl -s
```

---

## 12. Rollback and Recovery

### 12.1 Terraform Rollback

To revert a Terraform change, use `git revert` on the offending commit, then run `terraform apply` with the reverted code. Do not manually edit state. If a resource is in a broken state, use `terraform taint` to force re-creation.

```bash
git revert <commit-sha>
terraform plan -out=rollback.plan
terraform apply rollback.plan
```

### 12.2 Helm Rollback (Blueprint 02)

```bash
helm rollback <release-name> <revision-number>
```

Helm revision history is retained (default: 10 revisions). Customers should verify rollback success with `helm status <release-name>`.

### 12.3 Ansible Rollback (Blueprint 03)

Ansible playbooks include a `rollback` tag. The rollback play restores previous configuration from `/etc/aidome/backups/<timestamp>/` which is created before any destructive change:

```bash
ansible-playbook site.yml --tags rollback --extra-vars "rollback_to=<timestamp>"
```

### 12.4 EC2 Instance Replacement

Blueprint 01 treats EC2 instances as immutable. The correct rollback for a broken instance is to destroy and re-provision with the previous cloud-init configuration, not to SSH in and repair. AMI snapshots taken before major upgrades make this safe.

---

## 13. Blueprint Taxonomy

| # | Blueprint | Purpose | Primary tooling | OS support |
|---|---|---|---|---|
| 01 | AWS EC2 – Single Node | Customer onboarding: provision and harden a single EC2 instance ready for the AIdome installer | Terraform, CloudFormation, cloud-init | Debian 12, Ubuntu 22.04/24.04, RHEL 9, AlmaLinux 9 |
| 02 | HA Kubernetes | Production: multi-node EKS or self-managed Kubernetes cluster | Terraform, Helm | Kubernetes-managed (EKS AMI) |
| 03 | Air-Gapped | Restricted environments: fully offline deployment with no internet access | Ansible | RHEL 9, AlmaLinux 9 |

### Decision Points for Choosing a Blueprint

Use this flowchart to select the right blueprint:

```
Is internet access available?
├── No  → Blueprint 03 (Air-Gapped)
└── Yes → Is high availability required?
          ├── Yes → Blueprint 02 (HA Kubernetes)
          └── No  → Blueprint 01 (AWS EC2 – Single Node)
```

### Shared Modules

Reusable Terraform modules live in `shared/terraform-modules/`. They are consumed by blueprints via relative module paths and are not published to the Terraform Registry. Changes to shared modules must be reviewed for impact across all consuming blueprints.

| Module | Purpose | Consumed by |
|---|---|---|
| `networking/` | VPC, subnets, IGW, NAT Gateway, route tables | Blueprints that need a greenfield network |

---

## 14. Decision Log

This section records architectural decisions that are not obvious from the code itself. Full ADRs live in `docs/adr/` (to be created as decisions are formalised).

| ID | Decision | Rationale |
|---|---|---|
| D-001 | BYOV (Bring Your Own VPC) for all blueprints | Customers own their network perimeter. Blueprints must not impose CIDR choices or create VPC peering complexity. |
| D-002 | Prerequisites-only scope | Separates infrastructure concerns (this repo) from application lifecycle (AIdome team). Reduces blast radius of blueprint changes. |
| D-003 | Both Debian and RHEL cloud-init variants | Enterprise customers frequently standardise on RHEL-family; startup/cloud-native customers on Debian-family. Single OS would exclude a significant customer segment. |
| D-004 | `iptables` host firewall in addition to security groups | Defence in depth. Security groups can be inadvertently widened during VPC changes. Host firewall provides a catch. |
| D-005 | Pinned Docker CE version, not `latest` | Prevents unexpected breaking changes in container runtime from causing customer downtime during re-provisioning. |
| D-006 | Remote Terraform state (S3 + DynamoDB) | Prevents state file loss, enables team collaboration, and provides locking to prevent concurrent apply conflicts. |
| D-007 | `aidome-ops` user, not root SSH | Maintains auditability (all actions attributed to a named user) and least privilege (no unrestricted root shell). |
| D-008 | Air-gapped blueprint uses Ansible, not Terraform | Terraform requires network access to provider APIs. Ansible with an offline inventory file has no such dependency. |

