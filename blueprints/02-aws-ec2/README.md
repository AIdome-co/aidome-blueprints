# Blueprint 02 · AWS EC2

> Customer-facing EC2 blueprint. Provisions a hardened, private-subnet EC2 instance
> bootstrapped via cloud-init. Once up, the customer runs `aidome.sh` to install AIDome.

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
  │   │   │  (Ubuntu 24.04 LTS, no public IP) │    │  │
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
- Ubuntu 24.04 LTS AMI (`ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*`)
- **IAM instance profile** with `AmazonSSMManagedInstanceCore` policy — **required for SSM Session Manager access** (strongly recommended over SSH for private-subnet instances; without it, SSM will not work)

---

## Usage

### Terraform

```hcl
module "aidome_ec2" {
  source = "./blueprints/02-aws-ec2/terraform"

  vpc_id            = "vpc-xxxxxxxx"
  private_subnet_id = "subnet-xxxxxxxx"
  ami_id            = "ami-xxxxxxxx"  # Ubuntu 24.04 LTS (Noble)

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
  --template-file blueprints/02-aws-ec2/cloudformation/ec2-private.yaml \
  --stack-name aidome-ec2 \
  --parameter-overrides \
      VpcId=vpc-xxxxxxxx \
      PrivateSubnetId=subnet-xxxxxxxx \
      AmiId=ami-xxxxxxxx \
      IamInstanceProfileName=aidome-ssm-profile \
  --capabilities CAPABILITY_NAMED_IAM
```

Pass cloud-init content via the `CloudInitUserData` parameter (base64-encoded by the template).

---

## Post-boot: install AIDome

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

## Validation

Run these from the repository root before opening a PR that touches this blueprint:

```bash
# Terraform
terraform -chdir=blueprints/02-aws-ec2/terraform fmt -check -recursive
terraform -chdir=blueprints/02-aws-ec2/terraform init -backend=false
terraform -chdir=blueprints/02-aws-ec2/terraform validate

# CloudFormation
cfn-lint blueprints/02-aws-ec2/cloudformation/ec2-private.yaml

# cloud-init YAML
yamllint blueprints/02-aws-ec2/scripts/cloud-init.yaml
```

CI runs the equivalent checks in [`.github/workflows/validate.yml`](../../.github/workflows/validate.yml).

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
