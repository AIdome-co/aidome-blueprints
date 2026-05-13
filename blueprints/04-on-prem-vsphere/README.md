# Blueprint 04 · VMware vSphere - Single Node

> **Scope - Infrastructure Prerequisites Only**
> This blueprint prepares a single Ubuntu VM on VMware vSphere for AIdome by provisioning the
> server environment: OS hardening, Docker Engine, firewall rules, `open-vm-tools`, and the
> `aidome-ops` operator account. The AIdome product installer (`aidome.sh`), application
> configuration, `.env` files, and container images are delivered separately by the AIdome team.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tested Platforms](#tested-platforms)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Cloud-Init Scripts](#cloud-init-scripts)
- [Security & Hardening](#security--hardening)
- [Secrets Handling](#secrets-handling)
- [Verify the Installation](#verify-the-installation)
- [Troubleshooting](#troubleshooting)
- [Getting the AIdome Installer](#getting-the-aidome-installer)
- [Rollback / Teardown](#rollback--teardown)
- [Repository Structure](#repository-structure)
- [Supported Operating Systems](#supported-operating-systems)
- [Further Reading](#further-reading)

---

## Overview

Blueprint 04 deploys a production-ready, single-node VMware vSphere virtual machine for customers
who want to run AIdome on an internet-connected on-premises virtualization platform instead of AWS.
Terraform clones a cloud-image template, injects cloud-init through VMware GuestInfo, and applies
baseline hardening at first boot.

Use this blueprint when:

- you operate VMware vSphere 7 or 8
- you want a single-node deployment in your own datacenter
- your environment is **not** fully air-gapped

If your environment is fully offline, use [Blueprint 03 · Air-Gapped](../03-air-gapped/README.md)
instead.

---

## Architecture

```text
 Customer / Operator
        │
        │  terraform plan/apply
        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │                         vCenter                            │
 │                                                             │
 │  Datacenter                                                 │
 │  ├─ Cluster / Resource Pool                                 │
 │  ├─ Datastore                                               │
 │  ├─ Port Group (customer-managed)                           │
 │  └─ Ubuntu cloud-image template                             │
 │           │                                                 │
 │           │ clone + guestinfo.userdata / guestinfo.metadata │
 │           ▼                                                 │
 │    ┌───────────────────────────────────────────────────┐    │
 │    │            AIdome vSphere VM                      │    │
 │    │  - UEFI + Secure Boot                             │    │
 │    │  - cloud-init bootstrap                           │    │
 │    │  - Docker Engine                                  │    │
 │    │  - iptables + DOCKER-USER                         │    │
 │    │  - fail2ban + auditd                              │    │
 │    │  - aidome-ops operator account                    │    │
 │    └───────────────────────────────────────────────────┘    │
 └─────────────────────────────────────────────────────────────┘
        │
        │  outbound HTTPS for package installation and AIdome delivery
        ▼
 Corporate internet egress / proxy
```

---

## Tested Platforms

This initial VMware blueprint is validated for the following baseline:

| Component | Supported baseline |
|---|---|
| VMware platform | vSphere 7.0 U3+ and vSphere 8.x |
| Guest template | Ubuntu 24.04 LTS cloud image template |
| Cloud-init transport | VMware GuestInfo (`guestinfo.userdata` / `guestinfo.metadata`) |
| Network mode | Static IPv4 on an existing port group |

> The source VM template must already include `cloud-init` and `open-vm-tools`. Ubuntu cloud-image
> templates satisfy this requirement and are the recommended starting point.

---

## Prerequisites

Before you deploy, ensure you have:

- **vCenter access** to the target datacenter, cluster, datastore, and port group
- A **cloud-image VM template** prepared in vCenter with:
  - `cloud-init` installed
  - `open-vm-tools` installed and enabled
  - UEFI firmware support for Secure Boot
- A **management subnet CIDR** that is allowed to SSH to the VM on port `22`
- **DNS**, **NTP**, and outbound **HTTPS/443** reachability for package installation
- **Terraform >= 1.5** installed locally

Recommended vCenter service-account scope:

- Read inventory on the target datacenter
- Clone virtual machine from the template
- Assign the VM to the target resource pool, datastore, and port group
- Power on and reconfigure the created VM

> Keep vCenter credentials outside Terraform files. Supply them with the standard provider
> environment variables: `VSPHERE_SERVER`, `VSPHERE_USER`, and `VSPHERE_PASSWORD`.

---

## Quick Start

```bash
# 1. Export provider credentials (use your secret manager or CI secret store)
export VSPHERE_SERVER="vcenter.example.com"
export VSPHERE_USER="terraform-svc@vsphere.local"
export VSPHERE_PASSWORD="..."

# 2. Navigate to the Terraform directory
cd blueprints/04-on-prem-vsphere/terraform

# 3. Copy the example vars file and fill in your values
cp terraform.tfvars.example terraform.tfvars

# 4. Initialise the provider
terraform init

# 5. Review the execution plan
terraform plan -var-file=terraform.tfvars
```

When the plan looks correct, apply it through your normal change-control process.

---

## Cloud-Init Scripts

This blueprint uses VMware GuestInfo to pass two payloads to the guest:

| File | Purpose |
|---|---|
| [`scripts/cloud-init-deb.yaml`](scripts/cloud-init-deb.yaml) | Ubuntu/Debian first-boot hardening and package installation |
| [`scripts/metadata.yaml`](scripts/metadata.yaml) | Hostname and static network configuration rendered by Terraform |

At first boot, cloud-init:

1. sets the hostname and static network configuration
2. creates the `aidome-ops` operator account
3. hardens SSH access (`PermitRootLogin no`, `PasswordAuthentication no`, `AllowUsers aidome-ops`)
4. installs Docker Engine from Docker's official Ubuntu repository
5. installs and enables `open-vm-tools`, `fail2ban`, `auditd`, and `netfilter-persistent`
6. applies iptables host-firewall rules, including the `DOCKER-USER` chain

---

## Security & Hardening

This blueprint applies secure defaults for an on-prem single-node deployment:

- **Private-by-default network posture** — the VM is attached to an existing private port group
- **Narrow SSH exposure** — inbound port `22` is restricted to the management CIDR you provide
- **UEFI Secure Boot** — enabled by default in Terraform
- **Host firewall** — iptables default-drop on inbound traffic plus a `DOCKER-USER` policy chain
- **Operator-only access** — `aidome-ops` is the allowed interactive SSH account
- **Audit and intrusion prevention** — `auditd` and `fail2ban` are enabled on first boot

If your environment includes VMware NSX, apply a distributed firewall policy in front of the VM as
an additional control. This blueprint does not create NSX resources.

---

## Secrets Handling

- Do **not** put vCenter credentials in `.tf`, `.tfvars`, or shell history.
- Keep `terraform.tfvars` out of version control. Only commit
  [`terraform.tfvars.example`](terraform/terraform.tfvars.example).
- Store long-lived secrets in your enterprise secret manager.
- Treat SSH private keys and any future AIdome installer credentials as customer secrets.

---

## Verify the Installation

After provisioning, verify the VM from your management network:

```bash
ssh aidome-ops@<vm-ip> "cloud-init status --wait"
ssh aidome-ops@<vm-ip> "sudo cloud-init analyze show"
ssh aidome-ops@<vm-ip> "vmware-toolbox-cmd -v"
ssh aidome-ops@<vm-ip> "docker --version && sudo systemctl is-active docker"
ssh aidome-ops@<vm-ip> "sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|allowusers'"
ssh aidome-ops@<vm-ip> "sudo iptables -L -n --line-numbers"
ssh aidome-ops@<vm-ip> "sudo fail2ban-client status sshd"
ssh aidome-ops@<vm-ip> "sudo auditctl -s"
```

Expected outcomes:

- `cloud-init status --wait` completes successfully
- Docker is active
- `permitrootlogin no`, `passwordauthentication no`, and `allowusers aidome-ops` are present
- iptables shows an allow rule only for your management CIDR on `tcp/22`

---

## Troubleshooting

Common checks:

- `/var/log/cloud-init.log` and `/var/log/cloud-init-output.log`
- `sudo journalctl -u cloud-init -u docker -u ssh -u fail2ban`
- `sudo netplan get`
- `sudo vmware-toolbox-cmd info get guestinfo.metadata`

If the guest never receives its network configuration:

1. confirm the template includes `cloud-init` and `open-vm-tools`
2. confirm the port group, gateway, and DNS settings in `terraform.tfvars`
3. confirm the guest interface name matches `guest_network_interface_name`

---

## Getting the AIdome Installer

After the infrastructure prerequisites are complete, contact the AIdome team to receive the
customer-specific AIdome installer and deployment instructions.

---

## Rollback / Teardown

Preview the destroy plan first:

```bash
cd blueprints/04-on-prem-vsphere/terraform
terraform plan -destroy -var-file=terraform.tfvars
```

When you are ready to remove the VM, use:

```bash
terraform destroy -var-file=terraform.tfvars
```

Also clean up any out-of-band DNS or IPAM reservations that are managed outside Terraform.

---

## Repository Structure

```text
blueprints/04-on-prem-vsphere/
├── README.md
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
└── scripts/
    ├── cloud-init-deb.yaml
    └── metadata.yaml
```

---

## Supported Operating Systems

This blueprint currently ships with one supported guest bootstrap path:

| OS family | Status | File |
|---|---|---|
| Ubuntu 24.04 LTS cloud image | ✅ Supported | `scripts/cloud-init-deb.yaml` |

If you need a RHEL-family or fully offline VMware variant, use this blueprint as the starting point
and coordinate with the AIdome team.

---

## Further Reading

- [cloud-init VMware datasource](https://cloudinit.readthedocs.io/en/latest/reference/datasources/vmware.html)
- [Terraform vSphere provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [vsphere_virtual_machine resource](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/virtual_machine)
- [VMware Secure Boot overview](https://knowledge.broadcom.com/external/article?legacyId=2147608)
