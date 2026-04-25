terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  # Map os_type to OS family — drives cloud-init template selection.
  # Debian family (APT-based): ubuntu-2404, ubuntu-2204, debian-12 → cloud-init-deb.yaml
  # RHEL family (DNF-based):   centos-9, rhel-9, rhel-10, almalinux-9, oracle-9, rocky-9 → cloud-init-rhel.yaml
  #
  # NOTE: When adding a new os_type to variables.tf, update this map too.
  os_family_map = {
    "ubuntu-2404" = "deb"
    "ubuntu-2204" = "deb"
    "debian-12"   = "deb"
    "centos-9"    = "rhel"
    "rhel-9"      = "rhel"
    "rhel-10"     = "rhel"
    "almalinux-9" = "rhel"
    "oracle-9"    = "rhel"
    "rocky-9"     = "rhel"
  }

  os_family = local.os_family_map[var.os_type]

  # ── Local delivery ─────────────────────────────────────────────────────────
  # Used only when cloud_init_delivery = "local".
  # The file is gzip-compressed at plan time so it stays under the 16 KB EC2
  # user-data limit even for the larger Debian/RHEL scripts (> 22 KB raw).
  default_cloud_init_path            = "${path.module}/../scripts/cloud-init-${local.os_family}.yaml"
  effective_cloud_init_template_path = coalesce(var.cloud_init_template_path, local.default_cloud_init_path)
  cloud_init_file_exists             = var.cloud_init_delivery == "local" && fileexists(local.effective_cloud_init_template_path)
  cloud_init_user_data               = local.cloud_init_file_exists ? file(local.effective_cloud_init_template_path) : null

  # ── GitHub delivery ────────────────────────────────────────────────────────
  # Used when cloud_init_delivery = "github" (opt-in; "local" is the default).
  # cloud-init's #include directive fetches and processes the referenced URL at
  # first boot — the user-data payload is only ~100 bytes.
  # Pin github_ref to a release tag or commit SHA in production to prevent
  # unexpected changes at the next instance launch.
  github_cloud_init_url  = "https://raw.githubusercontent.com/AIdome-co/aidome-blueprints/${var.github_ref}/blueprints/01-aws-ec2/scripts/cloud-init-${local.os_family}.yaml"
  github_include_payload = "#include\n${local.github_cloud_init_url}\n"

  # ── Effective user-data (base64-encoded) ───────────────────────────────────
  # Always expressed as user_data_base64 to support both delivery paths:
  #   github → base64-encode of the tiny #include string
  #   local  → base64gzip of the full YAML (cloud-init transparently decompresses)
  effective_user_data_base64 = var.cloud_init_delivery == "github" ? base64encode(local.github_include_payload) : (
    local.cloud_init_user_data != null ? base64gzip(local.cloud_init_user_data) : null
  )
}

resource "aws_security_group" "vm_private_sg" {
  name_prefix = "${var.name_prefix}-private-"
  description = "AIDome EC2 private-subnet security group"
  vpc_id      = var.vpc_id

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "ssh_internal" {
  count = var.allowed_ssh_cidr == null ? 0 : 1

  security_group_id = aws_security_group.vm_private_sg.id
  description       = "Optional SSH access from internal CIDR"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_instance" "vm_instance" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = concat([aws_security_group.vm_private_sg.id], var.additional_security_group_ids)
  iam_instance_profile        = var.iam_instance_profile_name
  key_name                    = var.key_name
  associate_public_ip_address = false
  user_data_base64            = local.effective_user_data_base64

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_id
  }

  metadata_options {
    http_endpoint = "enabled"
    # Enforce IMDSv2 to reduce SSRF credential-exposure risk.
    http_tokens                 = "required"
    http_put_response_hop_limit = var.metadata_hop_limit
  }

  lifecycle {
    precondition {
      condition     = var.cloud_init_delivery != "local" || local.cloud_init_user_data != null
      error_message = "cloud-init template file not found: ${local.effective_cloud_init_template_path}"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-vm"
    }
  )
}
