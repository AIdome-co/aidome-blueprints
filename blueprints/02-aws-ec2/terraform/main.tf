terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ── Greenfield networking (create_vpc = true) ──────────────────────────────────

module "networking" {
  count  = var.create_vpc ? 1 : 0
  source = "../../../shared/terraform-modules/networking"

  availability_zone   = var.availability_zone
  name_prefix         = var.name_prefix
  private_subnet_cidr = var.private_subnet_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  tags                = var.tags
  vpc_cidr            = var.vpc_cidr
}

locals {
  effective_cloud_init_template_path = coalesce(var.cloud_init_template_path, "${path.module}/../scripts/cloud-init.yaml")
  cloud_init_user_data               = fileexists(local.effective_cloud_init_template_path) ? file(local.effective_cloud_init_template_path) : null

  # Resolve VPC / subnet IDs — use module outputs when create_vpc = true, otherwise
  # fall back to the caller-supplied variables.
  effective_vpc_id            = var.create_vpc ? module.networking[0].vpc_id : var.vpc_id
  effective_private_subnet_id = var.create_vpc ? module.networking[0].private_subnet_id : var.private_subnet_id
}

resource "aws_security_group" "vm_private_sg" {
  name_prefix = "${var.name_prefix}-private-"
  description = "AIDome EC2 private-subnet security group"
  vpc_id      = local.effective_vpc_id

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
  subnet_id                   = local.effective_private_subnet_id
  vpc_security_group_ids      = concat([aws_security_group.vm_private_sg.id], var.additional_security_group_ids)
  iam_instance_profile        = var.iam_instance_profile_name
  key_name                    = var.key_name
  associate_public_ip_address = false
  user_data                   = local.cloud_init_user_data

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
      condition     = var.create_vpc || (var.vpc_id != null && var.private_subnet_id != null)
      error_message = "Either set create_vpc = true, or provide both vpc_id and private_subnet_id."
    }
    precondition {
      condition     = local.cloud_init_user_data != null
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
