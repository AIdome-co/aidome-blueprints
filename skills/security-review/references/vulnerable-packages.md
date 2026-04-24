# Vulnerable & High-Risk Package Watchlist

Load this during Step 2 (Dependency Audit). Check versions in the project's lock files.

---

## npm / Node.js

| Package | Vulnerable Versions | Issue | Safe Version |
|---------|-------------------|-------|--------------|
| lodash | < 4.17.21 | Prototype pollution (CVE-2021-23337) | >= 4.17.21 |
| axios | < 1.6.0 | SSRF, open redirect | >= 1.6.0 |
| jsonwebtoken | < 9.0.0 | Algorithm confusion bypass | >= 9.0.0 |
| shelljs | < 0.8.5 | ReDoS | >= 0.8.5 |
| tar | < 6.1.9 | Path traversal | >= 6.1.9 |
| minimist | < 1.2.6 | Prototype pollution | >= 1.2.6 |
| qs | < 6.7.3 | Prototype pollution | >= 6.7.3 |
| express | < 4.19.2 | Open redirect | >= 4.19.2 |
| xml2js | < 0.5.0 | Prototype pollution | >= 0.5.0 |
| semver | < 7.5.2 | ReDoS | >= 7.5.2 |
| vm2 | ANY | Sandbox escape (deprecated) | Use isolated-vm instead |

---

## Python / pip

| Package | Vulnerable Versions | Issue | Safe Version |
|---------|-------------------|-------|--------------|
| Pillow | < 10.0.1 | Multiple CVEs, buffer overflow | >= 10.0.1 |
| cryptography | < 41.0.0 | OpenSSL vulnerabilities | >= 41.0.0 |
| PyYAML | < 6.0 | Arbitrary code via yaml.load() | >= 6.0 |
| paramiko | < 3.4.0 | Authentication bypass | >= 3.4.0 |
| requests | < 2.31.0 | Proxy auth info leak | >= 2.31.0 |
| urllib3 | < 2.0.7 | Header injection | >= 2.0.7 |
| Django | < 4.2.16 | Various | >= 4.2.16 |
| Flask | < 3.0.3 | Various | >= 3.0.3 |
| Jinja2 | < 3.1.4 | HTML attribute injection | >= 3.1.4 |
| aiohttp | < 3.9.4 | SSRF, path traversal | >= 3.9.4 |

---

## Java / Maven

| Package | Vulnerable Versions | Issue |
|---------|-------------------|-------|
| log4j-core | 2.0-2.14.1 | Log4Shell RCE (CVE-2021-44228) — CRITICAL |
| log4j-core | 2.15.0 | Incomplete fix — still vulnerable |
| Spring Framework | < 5.3.28, < 6.0.13 | Various CVEs |
| Apache Commons Text | < 1.10.0 | Text4Shell RCE (CVE-2022-42889) |

---

## General Red Flags (Any Ecosystem)

Flag any dependency that:
1. Has not been updated in > 2 years AND has > 10 open security issues
2. Has been deprecated by its maintainer with a security advisory
3. Is a fork of a known package from an unknown publisher (typosquatting)
4. Has a name that's one character off from a popular package
5. Was recently transferred to a new owner
