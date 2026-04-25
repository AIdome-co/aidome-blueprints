# Security Guidelines

Cross-cutting security expectations that apply to **every** blueprint in this repository. Blueprint-specific guidance (e.g., HA-only concerns in Kubernetes) belongs in the blueprint's own `README.md`.

For the AI-agent-facing version of these rules (used by GitHub Copilot, Codex, and Claude Code), see [`.github/instructions/security-iac.instructions.md`](../.github/instructions/security-iac.instructions.md).

---

## 1. Threat model

These blueprints are executed by **customers**, in **customer-owned** environments (AWS account, on-prem, air-gapped). We therefore defend against:

1. **Insecure defaults** leaking into a release — the single biggest IaC risk.
2. **Supply chain compromise** — upstream providers, Helm charts, container images, GitHub Actions.
3. **Secret exposure** — access keys / tokens / private keys in git history, `.tfstate`, logs, or outputs.
4. **Over-permissioned identities** — IAM / RBAC / Ansible privilege escalation wider than needed.
5. **Misconfigured network exposure** — public subnets, open security groups, missing TLS.

We do **not** assume the customer is adversarial, but we do assume they may misconfigure; blueprints should guide them toward safe defaults.

## 2. Identity & access

- **Least privilege** on every IAM policy, Kubernetes `Role` / `ClusterRole`, and Ansible `become:` block.
- **No long-lived access keys** in CI. Use GitHub Actions OIDC (`aws-actions/configure-aws-credentials` with `role-to-assume`).
- **Instance / pod identities** for workload credentials (EC2 instance profile, IRSA for EKS).
- **MFA** required for any human principal that can run `terraform apply` against production.

## 3. Secrets

- **Never** commit secrets, even temporarily. Use pre-commit `gitleaks` and enable GitHub Push Protection.
- Mark Terraform variables with `sensitive = true` and CloudFormation parameters with `NoEcho: true`.
- Reference secrets at runtime from a managed store:
  - AWS: Secrets Manager or SSM Parameter Store (`SecureString`)
  - On-prem / air-gapped: HashiCorp Vault or `ansible-vault`
  - Kubernetes: `Secret` + External Secrets Operator
- Rotate secrets on a schedule and after any suspected exposure. The blueprint README must document rotation.

## 4. Network posture

- **Private subnets by default.** Public subnets host only load balancers / NAT gateways.
- **Security groups / NSGs** start from deny-all. Never expose `22`, `3306`, `5432`, `6379`, `9200`, `27017`, `6443`, etc., to `0.0.0.0/0`.
- **IMDSv2 required** (`HttpTokens: required`, `HopLimit: 1`) on every EC2 instance.
- **TLS in transit** on every listener, and between services where the platform supports it.
- **Kubernetes NetworkPolicy**: default-deny, open per-service.

## 5. Data protection

- **Encryption at rest**: EBS, S3, RDS, EFS, DynamoDB, ElastiCache, Kubernetes Secrets backing store (etcd encryption config).
- **Customer-managed KMS keys** for regulated customers; otherwise AWS-managed keys are acceptable.
- **Key rotation**: `enable_key_rotation = true` on `aws_kms_key`.
- **Backups**: enabled with retention ≥ 7 days by default; blueprint-specific tuning documented in the blueprint README.

## 6. Supply chain

- **Pin versions** for Terraform (`required_version`), providers (`.terraform.lock.hcl` committed), Helm charts, Ansible collections (`requirements.yml`), container images (prefer digests `@sha256:...`), and GitHub Actions (by full commit SHA).
- **Dependabot / Renovate** watches `.github/dependabot.yml` for updates.
- **Image signing**: verify images with `cosign verify` where applicable.
- **SBOMs**: generate via Syft for any image we publish (tracked as future work).

## 7. State files

- **Remote state** for any multi-operator blueprint: S3 + DynamoDB lock, or Terraform Cloud / HCP Terraform.
- State bucket: **encrypted (`aws:kms`)**, **versioned**, with all four S3 Block Public Access flags **on**.
- IAM access to state is scoped to the specific principal (human or CI role) running Terraform.

## 8. Scanning in CI

`.github/workflows/validate.yml` runs (or should run) these on every PR:

| Tool | Scope |
|------|-------|
| `terraform fmt` + `terraform validate` + `tflint` | Terraform |
| `tfsec` or `checkov` | Terraform security |
| `cfn-lint` + `cfn-nag` (or `checkov`) | CloudFormation |
| `ansible-lint` + `yamllint` | Ansible |
| `helm lint` + `kubeconform` + `kube-linter` | Helm / K8s |
| `shellcheck` | Shell scripts |
| `gitleaks` | Secret scanning |

CI should fail on **High / Critical** findings. Medium findings may be suppressed inline with a justification comment and an issue link.

## 9. Customer-facing hardening expectations

Every blueprint's `README.md` must document:

- Minimum IAM permissions needed to deploy (as a policy JSON snippet).
- Network posture assumed (public, private, hybrid, air-gapped).
- How secrets are expected to be provided.
- How to rotate any long-lived credentials the blueprint creates.
- How to fully tear down (`terraform destroy` + any out-of-band cleanup).

## 10. Incident response

If a secret is ever committed or a vulnerability is identified:

1. Rotate the affected credential **immediately**.
2. Invalidate or revoke any issued tokens.
3. Open a private GitHub Security Advisory.
4. Document root cause and remediation in a blameless post-mortem linked from the blueprint README.

---

Questions or gaps? Open an issue tagged `security` or start a discussion. Never disclose a vulnerability in a public issue — see [`CONTRIBUTING.md`](../CONTRIBUTING.md#security-disclosures).
