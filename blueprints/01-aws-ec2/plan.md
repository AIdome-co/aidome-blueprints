# Blueprint 01 AWS EC2 Follow-up Plan

This file tracks the remaining gaps from the post-merge audit of PR #2 against the current `blueprints/01-aws-ec2` implementation.

## Done in PR #2

- [x] Added customer-facing `blueprints/01-aws-ec2/` blueprint with Terraform, CloudFormation, cloud-init, and README.
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

## Done in heatmap PR (this PR)

- [x] **OS support tier column** added to README OS table (Vendor / Community / Conditional / Experimental).
- [x] **Feature heatmap** added to README — expanded from 4 to 8 columns after gap resolution.
- [x] **SSH hardening: LogLevel VERBOSE** — added to both cloud-init scripts (CIS 5.2.5).
- [x] **SSH hardening: AllowUsers aidome-ops** — added to both cloud-init scripts (CIS 5.2.17).
- [x] **Sysctl: kernel.randomize_va_space = 2** — added to both cloud-init scripts (CIS 1.5.2 ASLR).
- [x] **auditd installed, enabled, and rules loaded** — `auditd` (Debian) / `audit` (RHEL) package added; `99-aidome-cis.rules` written to `/etc/audit/rules.d/`; `augenrules --load` called in runcmd (CIS 4.1.3/4/5/7/11/15/17).
- [x] **jq installed** — added to packages in both cloud-init scripts.
- [x] **AWS CLI v2 installed** — official binary installer from `awscli.amazonaws.com` added to runcmd in both scripts; `unzip` package dependency also added; GPG key `A6310ACC4672475C` verified.
- [x] **Heatmap CLI Tools column upgraded to 🟢** — all tools now fully installed.
- [x] **Heatmap expanded** — added columns for iptables Firewall, SSM Agent, CloudWatch Agent, Auto-updates, Package Cleanup.
- [x] **netfilter-persistent reload regression fixed** — `netfilter-persistent reload` re-added to `cloud-init-deb.yaml` runcmd so firewall rules are active immediately (not only after reboot).

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
- [x] Add CloudWatch Agent installation + metrics/log config — agent installed in cloud-init; ships data when `CloudWatchAgentServerPolicy` is attached to the instance role.
- [x] Add optional customer-managed KMS key support — `kms_key_id` variable in Terraform; `KmsKeyId` parameter in CloudFormation.
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
| ~~🟠 Medium~~ | ~~SSH `LogLevel VERBOSE` missing (CIS 5.2.5)~~ ✅ Fixed |
| ~~🟠 Medium~~ | ~~SSH `AllowUsers aidome-ops` missing (CIS 5.2.17)~~ ✅ Fixed |
| ~~🟠 Medium~~ | ~~`kernel.randomize_va_space = 2` missing (CIS 1.5.2)~~ ✅ Fixed |
| ~~🟠 Medium~~ | ~~`auditd` not installed (CIS 4.1.x)~~ ✅ Fixed — package installed, service enabled, CIS rules loaded via `augenrules` |
| ~~🟠 Medium~~ | ~~`jq` not installed~~ ✅ Fixed |
| ~~🟠 Medium~~ | ~~`AWS CLI v2` not installed~~ ✅ Fixed (GPG key `A6310ACC4672475C` confirmed correct) |
| ~~🟠 Medium~~ | ~~`netfilter-persistent reload` missing from `cloud-init-deb.yaml`~~ ✅ Fixed |
| ~~🟢 Low~~ | ~~Heatmap CLI Tools column showed 🟡 (partial) — now 🟢 (all installed)~~ ✅ Fixed |
| ~~🟢 Low~~ | ~~Heatmap missing columns (iptables, SSM, CW Agent, Auto-updates)~~ ✅ Fixed |
| 🟠 Medium | Host iptables SSH rule too broad vs `allowed_ssh_cidr` (requires cloud-init templating) |
| 🟠 Medium | CloudFormation bootstrap readiness (`CreationPolicy`/`cfn-signal`) |
| ~~🟢 Low~~ | ~~terraform.tfvars.example~~ ✅ Created |
| ~~🟢 Low~~ | ~~CloudWatch Agent + log shipping~~ ✅ Installed in cloud-init; active with `CloudWatchAgentServerPolicy` |
| ~~🟢 Low~~ | ~~Customer-managed KMS key for EBS~~ ✅ `kms_key_id` in TF; `KmsKeyId` in CFN |
| ~~🟢 Low~~ | ~~Ubuntu 22.04~~ ✅ Upgraded to Ubuntu 24.04 LTS (Noble) throughout |
| ~~🟢 Low~~ | ~~SSH: deprecated `ChallengeResponseAuthentication`~~ ✅ Replaced with `KbdInteractiveAuthentication` (OpenSSH 9.x) |
| ~~🟢 Low~~ | ~~UFW / iptables conflict on Ubuntu 24.04~~ ✅ UFW explicitly disabled in cloud-init |
| 🟢 Low | Tighter default egress rules with commented examples |
| 🟢 Low | Terraform remote backend guidance (left to customer) |
