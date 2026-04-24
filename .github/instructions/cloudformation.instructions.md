---
applyTo: '**/cloudformation/**/*.yaml, **/cloudformation/**/*.yml, **/*.cfn.yaml, **/*.cfn.yml'
description: 'CloudFormation conventions for aidome-blueprints — covering template structure, parameters, resource naming, security, and cfn-lint validation.'
---

# CloudFormation Conventions (aidome-blueprints)

CloudFormation is used in `blueprints/01-aws-ec2/cloudformation/` to give customers a click-to-deploy alternative to Terraform. These guidelines keep the two paths behaviourally equivalent and auditable.

## Template Structure

Use this canonical section order:

1. `AWSTemplateFormatVersion: '2010-09-09'`
2. `Description` — one sentence, starting with a verb (e.g., "Provisions a hardened private-subnet EC2 instance for AIDome installation.").
3. `Metadata` — group parameters for the AWS Console UX (`AWS::CloudFormation::Interface`).
4. `Parameters`
5. `Mappings`
6. `Conditions`
7. `Resources`
8. `Outputs`

Keep templates under ~1000 lines; split into nested stacks (`AWS::CloudFormation::Stack`) if larger.

## Parameters

- Every parameter needs `Type`, `Description`, and either `Default` or `AllowedValues`/`AllowedPattern`.
- Use `NoEcho: true` for any secret-like input (passwords, tokens). Prefer referencing a Secrets Manager ARN instead of passing the secret directly.
- Sensible defaults: `InstanceType: t3.large`, `VolumeSize: 100`, `VolumeType: gp3`.
- Use `SSM parameter` types (`AWS::SSM::Parameter::Value<...>`) for values that change across accounts/regions (e.g., latest AMI IDs via `/aws/service/canonical/ubuntu/...`).

## Resource Naming

- **Logical IDs**: PascalCase, descriptive, no environment suffix (e.g., `AidomeInstance`, not `AidomeInstanceProd`).
- **`Tags`**: every taggable resource gets `Name`, `Project: AIdome`, `Blueprint: 01-aws-ec2`, `ManagedBy: CloudFormation`.
- **Physical names**: avoid setting them unless required (let CloudFormation generate) to allow safe `Replace` updates.

## Security

- **IAM**: define instance roles via `AWS::IAM::Role` with `AssumeRolePolicyDocument` scoped to the single service (`ec2.amazonaws.com`). Grant **only** the managed policies needed (`AmazonSSMManagedInstanceCore` for Session Manager access is the baseline).
- **Security groups**: default to **no ingress**. Expose SSH only via SSM Session Manager, or via a bastion / VPN. Egress to `0.0.0.0/0` is acceptable for installation.
- **EBS**: `Encrypted: true` on every `AWS::EC2::Volume` and `BlockDeviceMapping`. Use a CMK (KMS key) for regulated customers.
- **IMDS**: set `MetadataOptions.HttpTokens: required` (IMDSv2 only) and `HttpPutResponseHopLimit: 1`.
- **Secrets**: reference via `{{resolve:secretsmanager:...}}` or `{{resolve:ssm-secure:...}}` — never inline.
- **Private subnets**: default `AssociatePublicIpAddress: false`. If the customer needs public access, that belongs in a separate stack for a load balancer, not on the instance.

## `UserData` / cloud-init

- Prefer a single `UserData: !Base64 |-` block that references a cloud-init YAML — or use **matching** `scripts/cloud-init.yaml` from the Terraform path, fetched at boot, so the two provisioning paths stay in sync.
- Exit non-zero from any step that should fail the bootstrap (`set -euo pipefail` at the top).
- Write a sentinel file (e.g., `/var/lib/aidome/cloud-init.done`) that `aidome.sh` can check.

## Outputs

- Expose: `InstanceId`, `PrivateIp`, `SessionManagerUrl` (deep link), `IamRoleArn`.
- Never output secrets, private keys, or full user-data.

## Validation & Linting

Run locally before committing:

```bash
cfn-lint blueprints/01-aws-ec2/cloudformation/*.yaml
aws cloudformation validate-template \
  --template-body file://blueprints/01-aws-ec2/cloudformation/ec2-private.yaml
```

For security posture:

```bash
cfn_nag_scan --input-path blueprints/01-aws-ec2/cloudformation/
# or
checkov -d blueprints/01-aws-ec2/cloudformation/ --framework cloudformation
```

## Review Checklist

- [ ] All parameters have `Description` and validation (`AllowedValues`/`AllowedPattern`)
- [ ] `NoEcho: true` on any secret-like parameter
- [ ] IAM role is scoped to least-privilege; no `*` resources without justification
- [ ] Security group has no `0.0.0.0/0` ingress on SSH / DB ports
- [ ] EBS volumes are encrypted
- [ ] `MetadataOptions.HttpTokens: required` on EC2 instances
- [ ] Resources are tagged with `Project`, `Blueprint`, `ManagedBy`
- [ ] Outputs do not leak secrets
- [ ] `cfn-lint` passes with zero errors
- [ ] Behaviour matches the Terraform variant in the sibling `terraform/` directory
