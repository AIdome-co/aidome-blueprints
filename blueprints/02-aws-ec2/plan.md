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

- [ ] **Host iptables vs allowed_ssh_cidr mismatch**: the AWS Security Group is CIDR-aware but iptables accepts SSH from any source (`-A INPUT -p tcp --dport 22 -j ACCEPT`). For defense-in-depth these should match.
- [ ] **CloudFormation cloud-init delivery**: `CloudInitUserData` is a raw string parameter with `NoEcho: true`. Customer must manually base64-encode or paste the full cloud-init YAML. No `cfn-init`/`cfn-signal`/`CreationPolicy` is used, so CloudFormation cannot confirm bootstrap success.
- [ ] **IAM instance profile optionality**: SSM Session Manager is recommended for private-subnet access, but the IAM instance profile is optional in both TF and CFN. Consider making it required or adding a validation warning.
- [ ] **Missing CIS sysctl parameters**: `net.ipv4.conf.all.log_martians = 1`, `net.ipv4.conf.default.log_martians = 1`, `net.ipv6.conf.all.accept_ra = 0`, `net.ipv6.conf.default.accept_ra = 0` (CIS 3.3.6-3.3.10).
- [ ] **Docker GPG keyring path**: code uses `/etc/apt/keyrings/docker.gpg`; Docker official docs now recommend `/usr/share/keyrings/docker-archive-keyring.gpg`. Both work, but the latter is the canonical path.

### Low priority

- [ ] Add `terraform.tfvars.example` for customer convenience.
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
| 🟠 Medium | Host iptables SSH rule too broad vs `allowed_ssh_cidr` |
| 🟠 Medium | CloudFormation cloud-init delivery UX (no cfn-signal) |
| 🟠 Medium | IAM instance profile should be required or warned |
| 🟠 Medium | 4 missing CIS sysctl parameters |
| 🟠 Medium | Docker GPG keyring non-canonical path |
| 🟢 Low | terraform.tfvars.example, CloudWatch, KMS, egress, backend |
