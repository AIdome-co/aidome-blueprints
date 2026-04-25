variable "name_prefix" {
  description = "Name prefix for created resources"
  type        = string
  default     = "aidome-ec2"
}

variable "vpc_id" {
  description = "VPC ID where resources are created"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for the EC2 instance"
  type        = string
}

variable "os_type" {
  description = "Operating system type for the EC2 instance. Drives the cloud-init bootstrap script selection. Supported values: ubuntu-2404 (vendor-recommended), ubuntu-2204, debian-12, centos-9, rhel-9, rhel-10, almalinux-9, oracle-9, rocky-9. See README for AMI lookup commands per OS type."
  type        = string
  default     = "ubuntu-2404"

  validation {
    condition = contains([
      "ubuntu-2404",
      "ubuntu-2204",
      "debian-12",
      "centos-9",
      "rhel-9",
      "rhel-10",
      "almalinux-9",
      "oracle-9",
      "rocky-9",
    ], var.os_type)
    error_message = "os_type must be one of: ubuntu-2404, ubuntu-2204, debian-12, centos-9, rhel-9, rhel-10, almalinux-9, oracle-9, rocky-9."
  }
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance. Must match the selected os_type. See README for per-OS AMI lookup commands. Ubuntu 24.04 LTS is the vendor-recommended choice."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Optional EC2 key pair name"
  type        = string
  default     = null
}

variable "iam_instance_profile_name" {
  description = "Optional IAM instance profile name (required for SSM Session Manager access)"
  type        = string
  default     = null
}

variable "allowed_ssh_cidr" {
  description = "Optional internal CIDR allowed to SSH on port 22"
  type        = string
  default     = null
}

variable "additional_security_group_ids" {
  description = "Additional security groups to attach to the instance"
  type        = list(string)
  default     = []
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 30
}

variable "metadata_hop_limit" {
  description = "IMDSv2 HTTP PUT response hop limit (1 for strongest isolation; increase only if required)"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Extra tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cloud_init_delivery" {
  description = <<-EOT
    Controls how the cloud-init configuration is delivered to the EC2 instance.

    "local" (default) — The cloud-init YAML is read from disk at plan/apply time,
    gzip-compressed, and base64-encoded before being embedded in user data. Both scripts
    compress to < 8 KB — well under the 16 KB EC2 limit — with zero runtime dependencies.
    Use this for air-gapped deployments or when a custom `cloud_init_template_path` is
    required.

    "github" — The instance downloads the cloud-init YAML at first boot using
    cloud-init's native #include directive. The file is fetched from the public GitHub
    repository at the ref specified by `github_ref`. Requires outbound HTTPS to
    raw.githubusercontent.com at boot time (NAT gateway or VPC endpoint required).
  EOT
  type        = string
  default     = "local"

  validation {
    condition     = contains(["github", "local"], var.cloud_init_delivery)
    error_message = "cloud_init_delivery must be either \"github\" or \"local\"."
  }
}

variable "github_ref" {
  description = <<-EOT
    Git ref (branch, tag, or commit SHA) used when cloud_init_delivery = "github".
    Pin to a specific release tag (e.g. "v1.2.0") or commit SHA in production to
    prevent unexpected changes at the next instance launch.
    Has no effect when cloud_init_delivery = "local".
  EOT
  type        = string
  default     = "main"
}

variable "cloud_init_template_path" {
  description = "Path to the cloud-init template consumed by this module when cloud_init_delivery = \"local\" (defaults to scripts/cloud-init-<os_family>.yaml)"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "Optional KMS key ID or ARN for EBS volume encryption (uses the AWS managed key aws/ebs if null)"
  type        = string
  default     = null
}
