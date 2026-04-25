---
name: conventional-commit
description: 'Prompt and workflow for generating conventional commit messages using a structured format. Guides users to create standardized, descriptive commit messages in line with the Conventional Commits specification, including instructions, examples, and validation.'
---

<!--
Source: https://github.com/github/awesome-copilot/blob/main/skills/conventional-commit/SKILL.md
License: MIT (github/awesome-copilot)
-->

### Instructions

This skill generates conventional commit messages following the [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/#specification).

### Workflow

**Follow these steps:**

1. Run `git status` to review changed files.
2. Run `git diff` or `git diff --cached` to inspect changes.
3. Stage your changes with `git add <file>`.
4. Construct your commit message using the structure below.

### Commit Message Structure

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat` — New feature or blueprint addition
- `fix` — Bug fix or configuration correction
- `docs` — Documentation changes only
- `style` — Formatting, missing semicolons, no logic change
- `refactor` — Code change that neither fixes a bug nor adds a feature
- `perf` — Performance improvement
- `test` — Adding missing tests or correcting existing tests
- `build` — Changes that affect the build system or dependencies
- `ci` — Changes to CI/CD configuration files and scripts
- `chore` — Updating grunt tasks etc; no production code change
- `revert` — Reverts a previous commit

### Examples for this IaC repo

```
feat(01-aws-ec2): add KMS key for EBS encryption
fix(01-aws-ec2): correct subnet CIDR calculation
docs(02-ha-kubernetes): update Helm values reference table
chore(deps): pin terraform aws provider to 5.50.0
ci(validate): add tfsec security scan to PR workflow
refactor(shared/terraform-modules): extract vpc into reusable module
feat(03-air-gapped): add ansible role for docker hardening
```

### Validation

- **type**: Must be one of the allowed types above
- **scope**: Optional, but recommended. Use blueprint name (e.g., `01-aws-ec2`), module name, or component name
- **description**: Required. Use the imperative mood (e.g., "add", not "added", "adds"). Max 72 chars
- **body**: Optional. Use for additional context, reasoning, or breaking change details
- **footer**: Use for breaking changes (`BREAKING CHANGE: description`) or issue references (`Closes #123`)

### Final Step

After constructing the message, run:

```bash
git commit -m "type(scope): description"
# Or for multi-line:
git commit
```
