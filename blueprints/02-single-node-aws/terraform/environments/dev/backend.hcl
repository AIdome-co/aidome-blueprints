# ---------------------------------------------------------------------------
# S3 backend configuration for the dev environment
# Usage:  terraform init -backend-config=environments/dev/backend.hcl
# ---------------------------------------------------------------------------

bucket         = "aidome-terraform-state-dev"
key            = "blueprints/02-single-node-aws/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "aidome-terraform-locks-dev"
