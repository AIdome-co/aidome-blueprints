# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short project identifier used in resource naming."
  type        = string
  default     = "aidome"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into the instance."
  type        = list(string)
  default     = []
}

variable "allowed_https_cidrs" {
  description = "List of CIDR blocks allowed to access the application over HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------

variable "ami_id" {
  description = "AMI ID for the instance. Defaults to latest Ubuntu 22.04 LTS via data source when empty."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.large"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "root_volume_size" {
  description = "Size (GiB) of the root EBS volume."
  type        = number
  default     = 50
}

variable "data_volume_size" {
  description = "Size (GiB) of the secondary data EBS volume (0 = no extra volume)."
  type        = number
  default     = 100
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "extra_tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
