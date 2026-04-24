# Blueprint 02 AWS EC2 Follow-up Plan

This file tracks the remaining gaps from the post-merge audit of PR #2 against the current `blueprints/02-aws-ec2` implementation.

## Done in PR #2

- Added customer-facing `blueprints/02-aws-ec2/` blueprint with Terraform, CloudFormation, cloud-init, and README.
- Renumbered later blueprints so AWS EC2 is blueprint 02.
- Restored and updated the root `README.md`.
- Switched Docker installation to the official APT repository flow.
- Added SSM Agent installation, a dedicated `aidome-ops` user, IMDSv2 enforcement, encrypted root volume, and ASCII architecture.

## Remaining follow-up items

- [ ] Align the operator-access story end to end: decide whether customers should SSH as `ubuntu` first, SSH directly as `aidome-ops`, or use SSM only, then make README and cloud-init consistent.
- [ ] If `/etc/issue.net` is meant to be shown on SSH login, add the corresponding `Banner` directive or remove the unused banner file.
- [ ] Decide whether host-level SSH firewalling should mirror `allowed_ssh_cidr`; today the security group is CIDR-aware but iptables accepts SSH from any source.
- [ ] Review Docker + iptables interaction and document or enforce the intended `DOCKER-USER` / published-port behavior before relying on host firewall rules for containerized workloads.
- [ ] Improve CloudFormation usability for `CloudInitUserData` so customers have a clear supported path to pass the bundled cloud-init payload.
- [ ] Decide whether the IAM instance profile for SSM should remain optional or become mandatory for the recommended private-subnet access path.
- [ ] Consider adding the missing hardening sysctls identified in the audit (`net.ipv4.conf.all.log_martians`, IPv6 `accept_ra` controls).
- [ ] Consider adding optional observability guidance or examples for CloudWatch log shipping and bootstrap log collection.
- [ ] Consider adding optional encryption and network-hardening knobs such as customer-managed KMS keys and tighter default egress examples.

## Priority

| Priority | Item |
|---|---|
| High | Access-flow consistency (`ubuntu` vs `aidome-ops` vs SSM-only) |
| High | Docker firewall behavior with container-published ports |
| Medium | CloudFormation cloud-init delivery usability |
| Medium | SSH banner / host-firewall consistency |
| Low | Extra sysctl, CloudWatch, KMS, and tighter egress options |
