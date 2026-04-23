# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# VPC & Networking
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-public"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "aidome" {
  name_prefix = "${local.name_prefix}-sg-"
  description = "AIdome single-node instance security group"
  vpc_id      = aws_vpc.this.id

  # SSH
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidrs
  }

  # Outbound – allow all (for package downloads, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# IAM Role (instance profile)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "aidome" {
  name_prefix = "${local.name_prefix}-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-role"
  })
}

resource "aws_iam_instance_profile" "aidome" {
  name_prefix = "${local.name_prefix}-profile-"
  role        = aws_iam_role.aidome.name
}

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------

resource "aws_instance" "aidome" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.aidome.id]
  iam_instance_profile   = aws_iam_instance_profile.aidome.name

  user_data                   = file("${path.module}/cloud-init.yaml")
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-instance"
  })
}

# ---------------------------------------------------------------------------
# Data Volume (optional)
# ---------------------------------------------------------------------------

resource "aws_ebs_volume" "data" {
  count = var.data_volume_size > 0 ? 1 : 0

  availability_zone = aws_instance.aidome.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = merge(var.extra_tags, {
    Name = "${local.name_prefix}-data"
  })
}

resource "aws_volume_attachment" "data" {
  count = var.data_volume_size > 0 ? 1 : 0

  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.data[0].id
  instance_id = aws_instance.aidome.id
}
