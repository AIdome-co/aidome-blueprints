# AIDome Demo VM Blueprint

This blueprint provisions a secure demo VM into an existing private subnet on AWS.

## Structure

```
demo-vm/
├── cloudformation/
│   └── ec2-private.yaml       # CloudFormation template for the demo VM
├── scripts/
│   └── demo-vm-cloud-init.yaml  # Cloud-init bootstrap configuration
└── terraform/
    ├── main.tf                # Terraform module (security group + EC2 instance)
    ├── variables.tf           # Input variables
    └── outputs.tf             # Output values
```

## What it provisions

- **EC2 instance** in a private subnet (no public IP)
- **Security group** with optional SSH ingress from a specified CIDR
- **Cloud-init** bootstrap that configures:
  - Hardened SSH on ports 22 and 14022
  - iptables firewall (IPv4 + IPv6) with RFC1918-scoped rules
  - Fail2ban intrusion prevention
  - Docker Engine (rootful)
  - Python virtual environment at `/opt/aidome_dev_venv`
  - Unattended upgrades and sysctl security hardening
- **Encrypted gp3 root volume** (30 GiB default)
- **IMDSv2 enforced** (hop limit = 1)

## Usage

### Terraform

```hcl
module "demo_vm" {
  source = "./aws/dev/demo-vm/terraform"

  vpc_id            = "vpc-xxxxxxxx"
  private_subnet_id = "subnet-xxxxxxxx"
  ami_id            = "ami-xxxxxxxx"

  # Optional
  key_name         = "my-key"
  allowed_ssh_cidr = "10.0.0.0/8"
  instance_type    = "t3.small"
  root_volume_size = 30
  tags = {
    Environment = "dev"
    Project     = "aidome"
  }
}
```

### CloudFormation

Deploy `cloudformation/ec2-private.yaml` with required parameters:
- `VpcId` — VPC to deploy into
- `PrivateSubnetId` — private subnet for the VM
- `AmiId` — Ubuntu/Amazon Linux 2023 AMI ID

Pass the cloud-init content via the `CloudInitUserData` parameter (base64-encoded by the template).

## Security notes

- SSH port 22 is open for initial boot; disable it after verifying port 14022 works.
- Restrict `AllowedSshCidr` / `allowed_ssh_cidr` to the narrowest practical range.
- Review and tighten egress rules before production use.
