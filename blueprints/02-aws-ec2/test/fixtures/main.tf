# Test fixture for Blueprint 02 integration tests
#
# Creates a minimal but representative AWS environment:
#   - VPC (10.10.0.0/16) with public + private subnets
#   - Internet Gateway + NAT Gateway (private subnet outbound access)
#   - IAM role + instance profile with AmazonSSMManagedInstanceCore
#   - Blueprint 02 module (EC2 instance in the private subnet)
#
# The NAT GW allows the private instance to reach the internet for:
#   - apt/dnf package installs during cloud-init
#   - SSM agent registration (ssm.{region}.amazonaws.com)
#   - CloudWatch Agent downloads
#
# Cost note: a NAT GW + t3.medium instance in us-east-1 runs ~$0.10/hour.
# Tests typically complete in 30–40 minutes, so cost per run ≈ $0.07.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for the test environment"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Unique name prefix for all test resources (avoids collisions in parallel runs)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance under test"
  type        = string
}

variable "os_type" {
  description = "OS type value to pass to the blueprint module (must match a valid os_type)"
  type        = string
  default     = "ubuntu-2404"
}

variable "instance_type" {
  description = "EC2 instance type for the test instance"
  type        = string
  default     = "t3.medium"
}

# ------------------------------------------------------------------------------
# Networking — VPC, IGW, public + private subnets, NAT GW
# ------------------------------------------------------------------------------

resource "aws_vpc" "test" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "${var.name_prefix}-vpc"
    ManagedBy = "terratest"
  }
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id

  tags = {
    Name      = "${var.name_prefix}-igw"
    ManagedBy = "terratest"
  }
}

# Public subnet — hosts the NAT Gateway.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.test.id
  cidr_block              = "10.10.0.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.name_prefix}-public"
    ManagedBy = "terratest"
  }
}

# Private subnet — hosts the blueprint EC2 instance (no public IP).
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.test.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name      = "${var.name_prefix}-private"
    ManagedBy = "terratest"
  }
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.test]

  tags = {
    Name      = "${var.name_prefix}-nat-eip"
    ManagedBy = "terratest"
  }
}

resource "aws_nat_gateway" "test" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.test]

  tags = {
    Name      = "${var.name_prefix}-natgw"
    ManagedBy = "terratest"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = {
    Name      = "${var.name_prefix}-public-rt"
    ManagedBy = "terratest"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.test.id
  }

  tags = {
    Name      = "${var.name_prefix}-private-rt"
    ManagedBy = "terratest"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------------------
# IAM — instance profile with SSM managed core policy
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.name_prefix}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name      = "${var.name_prefix}-ssm-role"
    ManagedBy = "terratest"
  }
}

# AmazonSSMManagedInstanceCore: allows SSM agent registration + Run Command.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatchAgentServerPolicy: allows CloudWatch Agent to push logs + metrics.
# This attachment mirrors real deployments; without it CW Agent logs a warning.
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# ------------------------------------------------------------------------------
# Blueprint module — EC2 instance in the private subnet
# ------------------------------------------------------------------------------

module "blueprint" {
  source = "../../terraform"

  name_prefix               = var.name_prefix
  vpc_id                    = aws_vpc.test.id
  private_subnet_id         = aws_subnet.private.id
  ami_id                    = var.ami_id
  os_type                   = var.os_type
  instance_type             = var.instance_type
  iam_instance_profile_name = aws_iam_instance_profile.ssm.name

  tags = {
    Environment = "test"
    ManagedBy   = "terratest"
  }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "instance_id" {
  description = "ID of the test EC2 instance (used by Terratest for SSM commands)"
  value       = module.blueprint.instance_id
}

output "vpc_id" {
  description = "ID of the test VPC"
  value       = aws_vpc.test.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}
