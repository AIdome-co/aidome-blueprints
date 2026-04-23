# AIDome Blueprints

Infrastructure blueprints for provisioning AIDome environments on cloud providers.

## Repository structure

```
blueprints-export/
└── aws/
    └── dev/
        └── demo-vm/           # Secure demo VM in a private subnet
            ├── cloudformation/
            │   └── ec2-private.yaml
            ├── scripts/
            │   └── demo-vm-cloud-init.yaml
            └── terraform/
                ├── main.tf
                ├── variables.tf
                └── outputs.tf
```

## Blueprints

| Path | Provider | Purpose |
|------|----------|---------|
| [`aws/dev/demo-vm`](aws/dev/demo-vm/README.md) | AWS | Hardened demo EC2 instance in a private subnet |

## Migration guide

This directory (`blueprints-export/`) contains the content that should live in the
[`AIdome-co/aidome-blueprints`](https://github.com/AIdome-co/aidome-blueprints) repository.

To bootstrap the blueprints repo:

```bash
# 1. Create the aidome-blueprints repo on GitHub (empty, no README)

# 2. Clone it locally
git clone https://github.com/AIdome-co/aidome-blueprints.git
cd aidome-blueprints

# 3. Create the feature branch
git checkout -b feat/dev-vm-templates

# 4. Copy the export
cp -r /path/to/aidome-deploy/blueprints-export/* .

# 5. Commit and push
git add .
git commit -m "feat: add aws/dev/demo-vm blueprint"
git push -u origin feat/dev-vm-templates

# 6. Open a PR from feat/dev-vm-templates -> main in aidome-blueprints
```
