---
mode: 'agent'
description: 'Review an IaC change (Terraform, CloudFormation, Ansible, Helm) against the aidome-blueprints standards — security, idempotency, drift, documentation.'
---

# Prompt: Review IaC Change

You are reviewing a pull request in `aidome-blueprints`. Run through **every** section below for the files changed in the diff and report findings as a markdown checklist with ✅ / ⚠️ / ❌ and a one-line explanation each.

## 1. Scope check

- Which blueprint(s) does this PR touch? If it touches > 1 blueprint, flag unless the change is clearly cross-cutting (e.g., `shared/`, `docs/`, `.github/`).
- Is the PR description clear about intent?

## 2. Security (see [`.github/instructions/security-iac.instructions.md`](../instructions/security-iac.instructions.md))

- [ ] No secrets in code, `*.tfvars`, defaults, outputs, logs, or user-data
- [ ] IAM least-privilege: no `Action: "*"` on `Resource: "*"` without justification
- [ ] Security groups do not expose sensitive ports (`22`, `3306`, `5432`, `6379`, etc.) to `0.0.0.0/0`
- [ ] EBS / S3 / RDS / K8s secrets encrypted at rest
- [ ] TLS in transit where applicable
- [ ] EC2 has `MetadataOptions.HttpTokens: required`
- [ ] Versions are pinned (Terraform `required_version`, provider `version`, Helm `version`, image tags/digests, Ansible collections, GH Actions by SHA)

## 3. Idempotency & correctness

- [ ] Terraform: no `local-exec` / `remote-exec` for anything that should be declarative
- [ ] Ansible: no bare `shell`/`command`/`raw` without `creates:`/`removes:`
- [ ] CloudFormation: `Replace` / `Update` behaviour considered for resources with physical names
- [ ] Helm: templates produce valid YAML for all reasonable `values.yaml` combinations (`helm template | kubeconform`)

## 4. Drift & rollback

- [ ] Change can be rolled back (documented `terraform destroy`, `helm rollback`, `ansible-playbook --tags rollback` path)
- [ ] No resources are destroyed + recreated when an in-place update would have sufficed
- [ ] State migrations (`moved {}`, `import {}`) used instead of tainting + recreating where possible

## 5. Style & lint

- [ ] `terraform fmt -check -recursive .` clean
- [ ] `tflint` clean
- [ ] `ansible-lint` + `yamllint` clean
- [ ] `cfn-lint` clean
- [ ] `helm lint` clean
- [ ] `shellcheck` clean
- [ ] `markdownlint` clean

## 6. Documentation

- [ ] Every new `variable` / `output` has `description` and `type`
- [ ] Every new CloudFormation `Parameter` has `Description` and constraints
- [ ] Blueprint `README.md` updated if user-facing behaviour changed
- [ ] Architecture diagram updated if topology changed
- [ ] Root `README.md` layout table reflects any file/directory additions
- [ ] Security notes in blueprint README cover IAM, secrets, teardown

## 7. Tests

- [ ] Terraform tests (`*.tftest.hcl`) added for new modules
- [ ] `helm template` smoke-tested
- [ ] Ansible `--check --diff` considered

## 8. PR hygiene

- [ ] Commit messages describe intent
- [ ] No accidentally committed `.terraform/`, `*.tfstate*`, `*.retry`, `kubeconfig`, private keys
- [ ] Small enough to review in < 30 minutes; if not, suggest splitting

End the review with a **summary block**:

```
Overall: <approve | request changes | needs discussion>
Must-fix: <count>
Should-fix: <count>
Nits: <count>
Top 3 issues: ...
```
