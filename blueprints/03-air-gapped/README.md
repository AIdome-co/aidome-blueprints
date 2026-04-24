# Blueprint 03 · Air-Gapped

> 📬 **Self-service documentation for this blueprint is not yet published here.**
> The deployment is **fully supported and operational today** — contact
> [support@aidome.co](mailto:support@aidome.co) to discuss your air-gapped requirements.

---

## Overview

Blueprint 03 deploys AIdome in a **fully isolated, internet-free environment** using
Ansible. All artifacts — container images, OS packages, and configuration — are
pre-staged and delivered by the AIdome team before installation begins.

---

## Target audience

- Regulated industries: **defense, government, finance, healthcare** operating under
  strict data-residency or network isolation requirements
- Environments that undergo regular security audits and cannot permit outbound
  connections during or after installation
- Customers whose procurement and security teams require all software to be scanned
  and approved before deployment

---

## Product installation

All AIdome container images are hosted at `images.aidome.co` and are
access-controlled per customer. For air-gapped deployments, the AIdome team produces
a signed, offline artifact bundle specific to your license. Installation is always
performed with AIdome team involvement.

To discuss an air-gapped deployment, contact [support@aidome.co](mailto:support@aidome.co)
with your target platform, OS, and network topology details.

