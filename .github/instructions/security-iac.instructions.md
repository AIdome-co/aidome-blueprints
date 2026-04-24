---
applyTo: '**/*.tf, **/cloudformation/**/*.yaml, **/cloudformation/**/*.yml, **/ansible/**/*.yaml, **/ansible/**/*.yml, **/helm/**/templates/**/*.yaml, **/helm/**/templates/**/*.yml, **/scripts/cloud-init.yaml'
description: 'IaC-focused security guidelines for aidome-blueprints — covering identity, secrets, network, data protection, supply chain, and scanning tooling.'
---

# Security Guidelines — Infrastructure as Code

This file is the IaC-focused counterpart of a traditional OWASP web application security rule set. The blueprints in this repo deploy infrastructure that a customer runs in their own AWS account, their own on-prem environment, or an air-gapped facility — the threat model is different from a hosted SaaS app.

## Threat Model (summary)

1. **Customer running the blueprint** — not adversarial, but may misuse it (e.g., attach a public IP).
2. **Supply chain** — upstream providers, modules, images, charts, and actions may be compromised.
3. **State file contents** — `terraform.tfstate` contains secrets, ARNs, and private IPs in plaintext.
4. **Credentials leak** — access keys, private keys, customer tokens accidentally committed.
5. **Insecure defaults** — the #1 risk for IaC is a sloppy default left in a release.

## Identity & Access (IAM, RBAC)

- **Least privilege, always.** Every IAM policy, K8s `Role`/`ClusterRole`, and Ansible `become:` use must be scoped to exactly what is needed.
- **No `Action: "*"`** on `Resource: "*"` — if you genuinely need broad privileges, leave a comment explaining why.
- **Use instance / pod identities**, not access keys:
  - AWS EC2 → IAM instance profile
  - EKS pods → IRSA (`eks.amazonaws.com/role-arn` on the service account)
  - GitHub Actions → OIDC federation (`aws-actions/configure-aws-credentials` with `role-to-assume`)
- **Bootstrap credentials** (used once to create the blueprint) must be clearly flagged as temporary and rotated after first deploy.

## Secrets

- **Never commit secrets.** Enforce with `gitleaks`, GitHub Push Protection, and a `.gitignore` that excludes `*.tfvars` (except `*.tfvars.example`), `*.retry`, `kubeconfig`, `*.pem`, `*.key`, `vault-password`, and `*.tfstate*`.
- **Secret stores** (choose by blueprint):
  - AWS blueprints → AWS Secrets Manager / SSM Parameter Store (`SecureString`)
  - On-prem / air-gapped → HashiCorp Vault or Ansible Vault
  - Kubernetes → K8s `Secret` + External Secrets Operator (preferred) or SealedSecrets
- **In Terraform**: mark every variable that can hold a secret `sensitive = true`. Do the same for outputs.
- **In CloudFormation**: use `NoEcho: true` on secret parameters; reference secrets via `{{resolve:secretsmanager:...}}`.
- **In Ansible**: secrets live in `group_vars/*/vault` files, encrypted with `ansible-vault`.

## Network

- **Private subnets by default.** EC2 instances, RDS, and EKS node groups go into private subnets. Public subnets hold only load balancers / NAT gateways.
- **Security groups** start from deny-all and open the minimum set of ports. No `0.0.0.0/0` on `22`, `3306`, `5432`, `6379`, `9200`, etc.
- **NetworkPolicy** for K8s: default-deny ingress + egress at the namespace level, open per-service.
- **TLS everywhere in transit.** ALB/NLB listeners use TLS 1.2+; internal service mesh encrypts pod-to-pod traffic.
- **IMDSv2 required** on every EC2 instance (`HttpTokens: required`).

## Data Protection

- **Encrypt at rest**: EBS (`encrypted = true`), S3 (`server_side_encryption_configuration` with `aws:kms` when regulated), RDS (`storage_encrypted = true`), DynamoDB (`server_side_encryption`), EFS.
- **Customer-managed KMS keys** when the customer is in a regulated industry; otherwise AWS-managed keys are acceptable.
- **Key rotation**: `enable_key_rotation = true` on every `aws_kms_key`.
- **Backups**: enabled with retention ≥ 7 days (blueprint-specific; tune in the blueprint README).

## Supply Chain

- **Pin everything**:
  - Terraform: `required_version`, provider `version` constraints, `.terraform.lock.hcl` committed.
  - Helm: `version:` in `Chart.yaml`'s dependencies.
  - Ansible: `ansible-galaxy collection install -r requirements.yml` with version pins.
  - Container images: **never `:latest`** — use a digest (`@sha256:...`) for production paths.
  - GitHub Actions: pin third-party actions by full commit SHA.
- **Signed images** (`cosign verify`) for anything we publish.
- **SBOM**: generate via Syft for any image produced by this repo (future work).
- **Dependabot / Renovate** on `.github/dependabot.yml` watching Terraform, Helm, Actions, and Ansible requirements.

## State Files

- **Remote state** (S3 + DynamoDB lock, or Terraform Cloud / HCP Terraform) — never local state in a multi-operator blueprint.
- **State bucket is encrypted** (`aws:kms`), versioned, and has `BlockPublicAcls` + `BlockPublicPolicy` + `IgnorePublicAcls` + `RestrictPublicBuckets`.
- **IAM access to state** is scoped to the specific principal running Terraform for that blueprint.

## Scanning Tooling

Run these locally and in CI:

| Tool | Scope | Notes |
|------|-------|-------|
| [`tfsec`](https://aquasecurity.github.io/tfsec/) | Terraform | Fast, focused rules |
| [`checkov`](https://www.checkov.io/) | Terraform, CFN, K8s, Helm, Dockerfile | Broader coverage; slower |
| [`cfn-lint`](https://github.com/aws-cloudformation/cfn-lint) | CloudFormation | Syntax + best-practice rules |
| [`cfn-nag`](https://github.com/stelligent/cfn_nag) | CloudFormation | Security-specific |
| [`kube-linter`](https://docs.kubelinter.io/) | K8s / Helm | Finds insecure defaults |
| [`kubeconform`](https://github.com/yannh/kubeconform) | K8s YAML | Schema validation |
| [`trivy`](https://aquasecurity.github.io/trivy/) | Config + images | Unified CVE + misconfig |
| [`ansible-lint`](https://ansible-lint.readthedocs.io/) | Ansible | Includes `security` rules |
| [`gitleaks`](https://github.com/gitleaks/gitleaks) | Repo history | Run on every push |

CI should fail on **High / Critical** findings. Medium findings may be suppressed with an inline comment that includes justification and an issue link.

## Customer-facing Hardening Expectations

Every blueprint README **must** document:

- The IAM permissions required to deploy (as a minimal policy JSON snippet).
- The network posture assumed (public, private, hybrid).
- How secrets are expected to be provided.
- How to rotate any long-lived credentials the blueprint creates.
- How to fully tear down (`terraform destroy` + any out-of-band cleanup).

## Quick Review Checklist

- [ ] No secret values in code, `.tfvars`, defaults, outputs, or logs
- [ ] Least-privilege IAM (no `*:*`); no long-lived access keys in CI
- [ ] Private subnets by default; no `0.0.0.0/0` on sensitive ports
- [ ] EBS / S3 / RDS / K8s Secrets encrypted at rest; TLS in transit
- [ ] IMDSv2 required on EC2
- [ ] Versions pinned (Terraform, providers, Helm, Ansible collections, images, Actions)
- [ ] Terraform state is remote, encrypted, and access-scoped
- [ ] `tfsec`/`checkov`/`cfn-lint` run in CI with fail-on-high
- [ ] `gitleaks` runs on push / PR
- [ ] Blueprint README documents IAM requirements, network posture, secret handling, and teardown
