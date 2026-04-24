---
name: security-review
description: 'AI-powered codebase security scanner that reasons about code like a security researcher — tracing data flows, understanding component interactions, and catching vulnerabilities that pattern-matching tools miss. Use this skill when asked to scan code for security vulnerabilities, find bugs, check for SQL injection, XSS, command injection, exposed API keys, hardcoded secrets, insecure dependencies, access control issues, or any request like "is my code secure?", "review for security issues", "audit this codebase", or "check for vulnerabilities". Covers injection flaws, authentication and access control bugs, secrets exposure, weak cryptography, insecure dependencies, and business logic issues across JavaScript, TypeScript, Python, Java, PHP, Go, Ruby, and Rust. Also covers IaC-specific issues: hardcoded credentials, overly permissive IAM, unencrypted storage, and public resource exposure in Terraform, Ansible, CloudFormation, and Helm.'
---

<!--
Source: https://github.com/github/awesome-copilot/blob/main/skills/security-review/SKILL.md
License: MIT (github/awesome-copilot)
-->

# Security Review

An AI-powered security scanner that reasons about your codebase the way a human security
researcher would — tracing data flows, understanding component interactions, and catching
vulnerabilities that pattern-matching tools miss.

## When to Use This Skill

Use this skill when the request involves:

- Scanning a codebase or file for security vulnerabilities
- Running a security review or vulnerability check
- Checking for SQL injection, XSS, command injection, or other injection flaws
- Finding exposed API keys, hardcoded secrets, or credentials in code
- Auditing dependencies for known CVEs
- Reviewing authentication, authorization, or access control logic
- Detecting insecure cryptography or weak randomness
- Reviewing IaC for hardcoded credentials, overly permissive IAM, unencrypted storage
- Performing a data flow analysis to trace user input to dangerous sinks
- Any request phrasing like "is my code secure?", "scan this file", or "check my repo for vulnerabilities"
- Running `/security-review` or `/security-review <path>`

## How This Skill Works

Unlike traditional static analysis tools that match patterns, this skill:
1. **Reads code like a security researcher** — understanding context, intent, and data flow
2. **Traces across files** — following how user input moves through your application
3. **Self-verifies findings** — re-examines each result to filter false positives
4. **Assigns severity ratings** — CRITICAL / HIGH / MEDIUM / LOW / INFO
5. **Proposes targeted patches** — every finding includes a concrete fix
6. **Requires human approval** — nothing is auto-applied; you always review first

## Execution Workflow

Follow these steps **in order** every time:

### Step 1 — Scope Resolution
Determine what to scan:
- If a path was provided (`/security-review src/auth/`), scan only that scope
- If no path given, scan the **entire project** starting from the root
- Identify the language(s) and framework(s) in use
- For IaC repos: identify Terraform, Ansible, CloudFormation, Helm usage
- Read `references/language-patterns.md` to load language-specific vulnerability patterns

### Step 2 — Dependency Audit
Before scanning source code, audit dependencies first (fast wins):
- **Terraform**: Check provider/module version constraints for pinning
- **Helm**: Check chart versions and image tags for pinning
- **Ansible**: Check collection versions
- **Node.js**: Check `package.json` + `package-lock.json`
- **Python**: Check `requirements.txt` / `pyproject.toml` / `Pipfile`
- Flag packages with known CVEs, deprecated crypto libs, or suspiciously old pinned versions
- Read `references/vulnerable-packages.md` for a curated watchlist

### Step 3 — Secrets & Exposure Scan
Scan ALL files (including IaC, config, env, CI/CD, Dockerfiles) for:
- Hardcoded API keys, tokens, passwords, private keys
- `.env` files accidentally committed
- Secrets in comments or debug logs
- Cloud credentials (AWS, GCP, Azure, Stripe, Twilio, etc.)
- Database connection strings with credentials embedded
- Terraform `tfvars` files with actual secrets (not examples)
- Ansible vault-bypassed plaintext values
- Read `references/secret-patterns.md` for regex patterns and entropy heuristics

### Step 4 — Vulnerability Deep Scan

**IaC-Specific Checks** (for this repository — always run these):
- Terraform/CloudFormation/Ansible/Helm files:
  - Hardcoded credentials or secrets
  - IAM policies with `*` in actions or resources
  - S3 buckets with public access not blocked
  - EBS/RDS/S3 without encryption enabled
  - Security groups with `0.0.0.0/0` inbound beyond 80/443
  - Resources in public subnets without explicit justification
  - Container images using `:latest` tag
  - Missing resource tagging
  - Overly permissive RBAC in Helm/Kubernetes manifests

**Injection Flaws** (for application code):
- SQL Injection, XSS, Command Injection, LDAP, Header, Log injection

**Authentication & Access Control**:
- Missing authentication on sensitive endpoints
- Broken object-level authorization (BOLA/IDOR)
- JWT weaknesses (alg:none, weak secrets, no expiry validation)
- Session fixation, missing CSRF protection

**Data Handling**:
- Sensitive data in logs, error messages, or API responses
- Missing encryption at rest or in transit
- Insecure deserialization, Path traversal, XXE, SSRF

**Cryptography**:
- Use of MD5, SHA1, DES for security purposes
- Weak random number generation

**Business Logic**:
- Race conditions (TOCTOU)
- Missing rate limiting on sensitive endpoints

### Step 5 — Cross-File Data Flow Analysis
For IaC: trace how resource configurations flow across modules and blueprints.
For application code: trace user-controlled input from entry points to sinks.

### Step 6 — Self-Verification Pass
For EACH finding:
1. Re-read the relevant code with fresh eyes
2. Ask: "Is this actually exploitable, or is there sanitization I missed?"
3. Check if a framework or middleware already handles this upstream
4. Downgrade or discard findings that aren't genuine vulnerabilities
5. Assign final severity: CRITICAL / HIGH / MEDIUM / LOW / INFO

### Step 7 — Generate Security Report
Output the full report in the format defined in `references/report-format.md`.

### Step 8 — Propose Patches
For every CRITICAL and HIGH finding, generate a concrete patch:
- Show the vulnerable code (before)
- Show the fixed code (after)
- Explain what changed and why
- Preserve the original code style, variable names, and structure

Explicitly state: **"Review each patch before applying. Nothing has been changed yet."**

## Severity Guide

| Severity | Meaning | Example |
|----------|---------|---------|
| 🔴 CRITICAL | Immediate exploitation risk, data breach likely | SQLi, RCE, auth bypass, hardcoded secrets |
| 🟠 HIGH | Serious vulnerability, exploit path exists | XSS, IDOR, overly permissive IAM, unencrypted storage |
| 🟡 MEDIUM | Exploitable with conditions or chaining | CSRF, open redirect, weak crypto, public S3 bucket |
| 🔵 LOW | Best practice violation, low direct risk | Missing tags, verbose errors, unpinned minor versions |
| ⚪ INFO | Observation worth noting, not a vulnerability | Outdated dependency (no CVE) |

## Output Rules

- **Always** produce a findings summary table first (counts by severity)
- **Never** auto-apply any patch — present patches for human review only
- **Always** include a confidence rating per finding (High / Medium / Low)
- **Group findings** by category, not by file
- **Be specific** — include file path, line number, and the exact vulnerable code snippet
- **Explain the risk** in plain English — what could an attacker do with this?
- If the codebase is clean, say so clearly: "No vulnerabilities found" with what was scanned

## Reference Files

- `references/vuln-categories.md` — Deep reference for every vulnerability category
- `references/secret-patterns.md` — Regex patterns and entropy-based detection
- `references/language-patterns.md` — Framework-specific vulnerability patterns
- `references/vulnerable-packages.md` — Curated CVE watchlist
- `references/report-format.md` — Structured output template for security reports
