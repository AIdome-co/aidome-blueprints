#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# validate-prep.sh — Verify that the EC2 instance is ready for AIdome
#
# Usage:
#   ./validate-prep.sh <public-ip> [ssh-key-path]
#
# Checks:
#   • cloud-init finished successfully
#   • Docker is installed and running
#   • Data volume is mounted at /data
#   • aidome user exists
#   • sysctl tuning is applied
# ---------------------------------------------------------------------------

set -euo pipefail

HOST="${1:?Usage: $0 <public-ip> [ssh-key-path]}"
KEY="${2:-~/.ssh/id_rsa}"
# NOTE: StrictHostKeyChecking=accept-new trusts the key on first connect but
# rejects changes on subsequent connections, protecting against MITM attacks
# after the initial handshake.  For production use, pre-populate known_hosts
# with the instance's host key from the EC2 console output.
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

ssh_cmd() {
  ssh ${SSH_OPTS} -i "${KEY}" "ubuntu@${HOST}" "$@"
}

PASS=0
FAIL=0

check() {
  local label="$1"; shift
  if ssh_cmd "$@" > /dev/null 2>&1; then
    echo "  ✅  ${label}"
    (( PASS++ ))
  else
    echo "  ❌  ${label}"
    (( FAIL++ ))
  fi
}

echo ""
echo "🔍 Validating AIdome EC2 preparation on ${HOST} …"
echo ""

check "cloud-init completed"      "test -f /run/cloud-init/aidome-ready"
check "Docker installed"           "command -v docker"
check "Docker daemon running"      "systemctl is-active docker"
check "Data volume mounted"        "mountpoint -q /data"
check "aidome user exists"         "id aidome"
check "vm.max_map_count = 262144"  "test \$(sysctl -n vm.max_map_count) -eq 262144"
check "/data/aidome dir exists"    "test -d /data/aidome"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
  echo "⚠️  Some checks failed — review cloud-init logs: /var/log/cloud-init-output.log"
  exit 1
fi

echo "🎉 Instance is ready for AIdome installation."
