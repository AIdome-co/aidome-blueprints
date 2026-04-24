# Blueprint 02 AWS EC2 Follow-up Plan

This file tracks the remaining gaps from the post-merge audit of PR #2 against the current `blueprints/02-aws-ec2` implementation.

## Done in PR #2

- [x] Added customer-facing `blueprints/02-aws-ec2/` blueprint with Terraform, CloudFormation, cloud-init, and README.
- [x] Renumbered later blueprints so AWS EC2 is blueprint 02.
- [x] Restored and updated the root `README.md`.
- [x] Switched Docker installation to the official APT repository flow (GPG-verified).
- [x] Added SSM Agent installation (snap + apt fallback).
- [x] Added dedicated `aidome-ops` non-root operator user.
- [x] IMDSv2 enforced (`http_tokens = required`, hop limit = 1).
- [x] Encrypted gp3 root volume.
- [x] ASCII architecture diagram in blueprint README.
- [x] CIS-aligned SSH hardening (PermitRootLogin no, PasswordAuthentication no, MaxAuthTries 3, AllowTcpForwarding no, etc.).
- [x] CIS-aligned sysctl kernel and network hardening (20+ parameters).
- [x] iptables defense-in-depth (IPv4 + IPv6, SSH open, HTTPS from RFC1918 only).
- [x] fail2ban intrusion prevention (5 retries, 1-hour ban).
- [x] Unattended security upgrades.
- [x] Terraform + CloudFormation parity for core EC2 provisioning.
- [x] Tags on all resources.

## Remaining follow-up items

### High priority

- [x] **Operator-access consistency**: README now shows `ssh aidome-ops@` (was `ubuntu@`); SSM Session Manager remains the recommended path.
- [x] **SSH Banner directive (CIS 5.2.18)**: added `Banner /etc/issue.net` to sshd hardening config.
- [x] **Docker + iptables interaction**: added `DOCKER-USER` chain with RFC1918-only allow rules to `rules.v4`.

### Medium priority

- [x] **Missing CIS sysctl parameters**: added `net.ipv4.conf.all.log_martians = 1`, `net.ipv4.conf.default.log_martians = 1`, `net.ipv6.conf.all.accept_ra = 0`, `net.ipv6.conf.default.accept_ra = 0` (CIS 3.3.6–3.3.10).
- [x] **Docker GPG keyring path**: current code uses `/etc/apt/keyrings/docker.gpg`, which is the path shown in current Docker official documentation for Ubuntu. No change needed.
- [x] **IAM instance profile optionality**: Pre-requisites section in README now explicitly marks the IAM profile as **required for SSM access** and explains the consequence of omitting it.
- [x] **VPC endpoint guidance**: README now documents the three required VPC Interface Endpoints (`ssm`, `ssmmessages`, `ec2messages`) for private-subnet deployments without a NAT Gateway.
- [ ] **Host iptables vs allowed_ssh_cidr mismatch**: host iptables accepts SSH from any source; the AWS Security Group is CIDR-aware. Closing the gap requires cloud-init templating (passing `allowed_ssh_cidr` into cloud-init via `templatefile()`) — left for a follow-up to avoid making cloud-init provider-specific.
- [ ] **CloudFormation cloud-init delivery**: `CloudInitUserData` is provided as a raw parameter and base64-encoded by `Fn::Base64` in the template (no manual encoding needed by the customer). However, `CreationPolicy`/`cfn-signal` bootstrap readiness signaling is still absent — left for follow-up since the cloud-init content is customer-supplied, making cfn-signal injection non-trivial.

### Low priority

- [x] Add `terraform.tfvars.example` — created at `terraform/terraform.tfvars.example`.
- [ ] Add optional CloudWatch Agent / log-shipping guidance.
- [ ] Add optional customer-managed KMS key support for EBS encryption.
- [ ] Consider tighter default egress rules with commented examples.
- [ ] Consider adding Terraform remote backend guidance (left to customer intentionally).

## Priority summary

| Priority | Item |
|---|---|
| ~~🔴 High~~ | ~~Operator-access flow consistency (`ubuntu` vs `aidome-ops` vs SSM)~~ ✅ Fixed |
| ~~🔴 High~~ | ~~SSH `Banner /etc/issue.net` directive missing (CIS 5.2.18)~~ ✅ Fixed |
| ~~🔴 High~~ | ~~Docker + iptables / DOCKER-USER chain not handled~~ ✅ Fixed |
| ~~🟠 Medium~~ | ~~4 missing CIS sysctl parameters~~ ✅ Fixed |
| ~~🟠 Medium~~ | ~~Docker GPG keyring path~~ ✅ Already aligned with current Docker docs |
| ~~🟠 Medium~~ | ~~IAM instance profile should be required or warned~~ ✅ README updated |
| ~~🟠 Medium~~ | ~~VPC endpoint guidance missing~~ ✅ README updated |
| 🟠 Medium | Host iptables SSH rule too broad vs `allowed_ssh_cidr` (requires cloud-init templating) |
| 🟠 Medium | CloudFormation bootstrap readiness (`CreationPolicy`/`cfn-signal`) |
| ~~🟢 Low~~ | ~~terraform.tfvars.example~~ ✅ Created |
| 🟢 Low | CloudWatch, KMS, egress tightening, remote backend guidance |
