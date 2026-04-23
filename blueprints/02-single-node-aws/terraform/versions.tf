terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state:
  # backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aidome"
      Blueprint   = "02-single-node-aws"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
