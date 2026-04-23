# ---------------------------------------------------------------------------
# Dev environment values for AIdome single-node AWS blueprint
# Usage:  terraform apply -var-file=environments/dev/terraform.tfvars
# ---------------------------------------------------------------------------

aws_region   = "us-east-1"
environment  = "dev"
project_name = "aidome"

instance_type    = "t3.large"
root_volume_size = 50
data_volume_size = 100

# REQUIRED — set to the name of your EC2 key pair
ssh_key_name = "aidome-dev-key"

# Restrict SSH to your IP; replace with your CIDR
allowed_ssh_cidrs   = []
allowed_https_cidrs = ["0.0.0.0/0"]

extra_tags = {
  Team = "platform"
}
