#!/usr/bin/env bash
#
# AIdome VMware vSphere — Bootstrap Script for Pre-Installed Ubuntu Server
# =========================================================================
# Equivalent of cloud-init.yaml / cloud-init-deb.yaml for VMs where cloud-init
# was never configured or has already run. Intended for Ubuntu Server 22.04 or
# 24.04 LTS that a customer provides pre-installed.
#
# What this script does (mirrors the cloud-init hardening):
#   1. Creates the aidome-ops operator account with SSH key
#   2. Hardens SSH (port 22, key-only, AllowUsers aidome-ops)
#   3. Installs and configures fail2ban
#   4. Installs and loads CIS 4.1.x auditd rules
#   5. Applies sysctl kernel/network hardening (CIS 1.5.2, 3.3.x)
#   6. Installs iptables host firewall (v4 + v6) with DOCKER-USER chain
#   7. Installs Docker Engine from Docker's official APT repository (GPG-verified)
#   8. Installs open-vm-tools
#   9. Enables unattended-upgrades
#  10. Optionally reboots to apply all kernel/network settings
#
# Usage:
#   sudo bash bootstrap-server.sh --ssh-key "ssh-ed25519 AAAA..." --allowed-ssh-cidr 10.0.0.0/8
#   sudo bash bootstrap-server.sh --ssh-key-file /path/to/key.pub --allowed-ssh-cidr 192.168.1.0/24
#   sudo bash bootstrap-server.sh --ssh-key "ssh-ed25519 AAAA..." --hostname myhost --allowed-ssh-cidr 10.0.0.0/8 --reboot
#
# Requirements:
#   - Ubuntu Server 22.04 LTS or 24.04 LTS
#   - Root or sudo access
#   - Outbound HTTPS connectivity for package installation
#
# Version: 1.0
# =========================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Colour helpers (stripped when stdout is not a terminal)
# --------------------------------------------------------------------------
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
banner(){ echo -e "${BLUE}=== $* ===${NC}"; }

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------
VM_HOSTNAME=""
SSH_PUBLIC_KEY=""
SSH_KEY_FILE=""
ALLOWED_SSH_CIDR=""
DO_REBOOT="false"
OPERATOR_USER="aidome-ops"
SSH_PORT="22"
DOCKER_GPG_FINGERPRINT="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"

# --------------------------------------------------------------------------
# Usage
# --------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: sudo bash $(basename "$0") [OPTIONS]

Required:
  --ssh-key KEY           SSH public key string for ${OPERATOR_USER}
    OR
  --ssh-key-file FILE     Path to SSH public key file for ${OPERATOR_USER}

  --allowed-ssh-cidr CIDR Management CIDR allowed to SSH (e.g. 10.0.0.0/8).
                          SSH is private-network only — no default is provided
                          to prevent accidental public exposure.

Optional:
  --hostname NAME         Set the VM hostname (default: keep current)
  --reboot                Reboot after setup completes
  -h, --help              Show this help

Network posture:
  Port 443 (HTTPS) is open to ALL sources — this is the customer-facing interface.
  Port 22  (SSH)   is restricted to --allowed-ssh-cidr only.

Example:
  sudo bash $(basename "$0") --ssh-key "ssh-ed25519 AAAA..." --allowed-ssh-cidr 10.0.0.0/8 --hostname aidome-vsphere --reboot
EOF
  exit 0
}

# --------------------------------------------------------------------------
# Parse arguments
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-key)       SSH_PUBLIC_KEY="$2"; shift 2 ;;
    --ssh-key-file)  SSH_KEY_FILE="$2";   shift 2 ;;
    --hostname)      VM_HOSTNAME="$2";    shift 2 ;;
    --allowed-ssh-cidr) ALLOWED_SSH_CIDR="$2"; shift 2 ;;
    --reboot)        DO_REBOOT="true";    shift   ;;
    -h|--help)       usage ;;
    *) error "Unknown option: $1"; usage ;;
  esac
done

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  error "This script must be run as root (or with sudo)."
  exit 1
fi

# Resolve SSH key
if [[ -n "$SSH_KEY_FILE" ]]; then
  if [[ ! -f "$SSH_KEY_FILE" ]]; then
    error "SSH key file not found: $SSH_KEY_FILE"
    exit 1
  fi
  SSH_PUBLIC_KEY="$(cat "$SSH_KEY_FILE")"
fi

if [[ -z "$SSH_PUBLIC_KEY" ]]; then
  error "An SSH public key is required. Use --ssh-key or --ssh-key-file."
  exit 1
fi

if [[ -z "$ALLOWED_SSH_CIDR" ]]; then
  error "--allowed-ssh-cidr is required (e.g. 10.0.0.0/8, 192.168.1.0/24)."
  error "SSH must be restricted to a private/management network."
  exit 1
fi

# Verify we are on a supported Ubuntu Server release
if [[ ! -f /etc/os-release ]]; then
  error "/etc/os-release not found — unsupported OS."
  exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release

if [[ "$ID" != "ubuntu" ]]; then
  error "This script supports Ubuntu only (detected: $ID)."
  exit 1
fi

MAJOR_VERSION="${VERSION_ID%%.*}"
if [[ "$MAJOR_VERSION" -lt 22 ]]; then
  error "Ubuntu 22.04 or later is required (detected: $VERSION_ID)."
  exit 1
fi

# Detect if a desktop environment is installed
if dpkg -l ubuntu-desktop &>/dev/null || dpkg -l ubuntu-desktop-minimal &>/dev/null; then
  warn "A desktop environment is installed. This script is intended for Ubuntu Server."
  warn "Use bootstrap-desktop.sh instead for Ubuntu Desktop systems."
  warn "Continuing anyway — desktop services will NOT be removed by this script."
fi

banner "AIdome VMware vSphere — Server Bootstrap"
log "OS: $PRETTY_NAME"
log "Operator user: $OPERATOR_USER"
log "SSH port: $SSH_PORT"
log "Allowed SSH CIDR: $ALLOWED_SSH_CIDR"
log "Start time: $(date -u)"

# --------------------------------------------------------------------------
# 0. Set hostname (optional)
# --------------------------------------------------------------------------
if [[ -n "$VM_HOSTNAME" ]]; then
  banner "Setting hostname"
  hostnamectl set-hostname "$VM_HOSTNAME"
  # Update /etc/hosts if needed
  if ! grep -q "$VM_HOSTNAME" /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${VM_HOSTNAME}/" /etc/hosts \
      || echo -e "127.0.1.1\t${VM_HOSTNAME}" >> /etc/hosts
  fi
  log "Hostname set to $VM_HOSTNAME"
fi

# --------------------------------------------------------------------------
# 1. APT configuration and package installation
# --------------------------------------------------------------------------
banner "Configuring APT and installing packages"

export DEBIAN_FRONTEND=noninteractive

# Preconfigure debconf for iptables-persistent
echo 'iptables-persistent iptables-persistent/autosave_v4 boolean false' | debconf-set-selections
echo 'iptables-persistent iptables-persistent/autosave_v6 boolean false' | debconf-set-selections

# APT hardening — same as cloud-init
cat > /etc/apt/apt.conf.d/99-aidome <<'APTCONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Install-Recommends "false";
APT::Get::Assume-Yes "true";
Dpkg::Options::="--force-confdef";
Dpkg::Options::="--force-confold";
APTCONF

# Remove conflicting Docker packages that may exist on a pre-installed VM
# (per official Docker docs: https://docs.docker.com/engine/install/ubuntu/)
apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc \
  podman-docker containerd runc 2>/dev/null || true

apt-get update -qq
apt-get upgrade -y

PACKAGES=(
  vim curl htop wget ca-certificates gnupg lsb-release python3 git
  net-tools dnsutils iproute2 traceroute mtr
  iptables-persistent netfilter-persistent
  fail2ban python3-systemd unattended-upgrades
  jq unzip
  auditd audispd-plugins
  open-vm-tools
)

apt-get install -y "${PACKAGES[@]}"
log "Packages installed"

# --------------------------------------------------------------------------
# 2. Create aidome-ops operator account
# --------------------------------------------------------------------------
banner "Creating operator account: $OPERATOR_USER"

if id "$OPERATOR_USER" &>/dev/null; then
  log "User $OPERATOR_USER already exists — updating groups and SSH key"
else
  useradd -m -s /bin/bash -G sudo,adm "$OPERATOR_USER"
  log "User $OPERATOR_USER created"
fi

# Ensure groups (docker group is added after Docker install)
usermod -aG sudo,adm "$OPERATOR_USER" 2>/dev/null || true

# Passwordless sudo
echo "${OPERATOR_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${OPERATOR_USER}"
chmod 0440 "/etc/sudoers.d/90-${OPERATOR_USER}"

# Lock password (SSH key only)
passwd -l "$OPERATOR_USER" >/dev/null 2>&1 || true

# SSH key
OPERATOR_HOME="$(eval echo "~${OPERATOR_USER}")"
mkdir -p "${OPERATOR_HOME}/.ssh"
chmod 700 "${OPERATOR_HOME}/.ssh"

# Append key if not already present
if ! grep -qF "$SSH_PUBLIC_KEY" "${OPERATOR_HOME}/.ssh/authorized_keys" 2>/dev/null; then
  echo "$SSH_PUBLIC_KEY" >> "${OPERATOR_HOME}/.ssh/authorized_keys"
fi
chmod 600 "${OPERATOR_HOME}/.ssh/authorized_keys"
chown -R "${OPERATOR_USER}:${OPERATOR_USER}" "${OPERATOR_HOME}/.ssh"

log "Operator account configured with SSH key"

# --------------------------------------------------------------------------
# 3. SSH hardening
# --------------------------------------------------------------------------
banner "Hardening SSH"

cat > /etc/ssh/sshd_config.d/60-aidome-hardening.conf <<EOF
Port ${SSH_PORT}
AddressFamily any

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
UsePAM yes

# Security hardening
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2

# Disable insecure features
PermitEmptyPasswords no
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression no
AllowTcpForwarding no
AllowAgentForwarding no
GatewayPorts no
PermitTunnel no

# CIS 5.2.18 — display /etc/issue.net before authentication
Banner /etc/issue.net

# CIS 5.2.5 — verbose auth logging captures detailed failed-auth information
LogLevel VERBOSE

# CIS 5.2.17 — restrict SSH logins to the designated operator account only
AllowUsers ${OPERATOR_USER}
EOF

# System banner
cat > /etc/issue.net <<'BANNER'
******************************************************************
*                   AIdome VMware vSphere System                 *
*                                                                *
*  WARNING: Unauthorized access is prohibited and will be       *
*  prosecuted to the full extent of the law.                    *
*                                                                *
*  All activities on this system are monitored and logged.      *
******************************************************************
BANNER

# MOTD
DISPLAY_HOSTNAME="${VM_HOSTNAME:-$(hostname)}"
cat > /etc/motd <<EOF

Welcome to AIdome VMware vSphere
==================================

System Information:
- Hostname: ${DISPLAY_HOSTNAME}
- Docker: Docker Engine (rootful)
- VMware Tools: open-vm-tools

Quick Start — install AIdome:
1. Connect via SSH
2. Run the AIdome installer (obtain the URL from your AIdome account or support team):
   curl -fsSL https://<your-aidome-download-url>/aidome.sh | sudo bash
3. Check Docker: docker ps
4. Check firewall rules: sudo iptables -L -n

Documentation: See /var/log/cloud-init.log

EOF

sleep 1
systemctl restart ssh || systemctl restart sshd || warn "SSH restart failed"
log "SSH hardened on port $SSH_PORT"

# --------------------------------------------------------------------------
# 4. Sysctl security hardening (CIS 1.5.2, 3.3.x)
# --------------------------------------------------------------------------
banner "Applying sysctl hardening"

cat > /etc/sysctl.d/99-aidome-security.conf <<'SYSCTL'
# Security Configuration

# IP Forwarding — disabled by default; uncomment only if VPN/routing is required
# net.ipv4.ip_forward = 1
# net.ipv6.conf.all.forwarding = 1

# Network security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Log martian packets (CIS 3.3.7)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# IPv6 security
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# Disable IPv6 router advertisements (CIS 3.3.10)
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# TCP hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Kernel security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# File system security
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Address Space Layout Randomization — prevents memory-based exploits (CIS 1.5.2)
kernel.randomize_va_space = 2
SYSCTL

sysctl -p /etc/sysctl.d/99-aidome-security.conf || warn "sysctl apply failed"
log "Sysctl hardening applied"

# --------------------------------------------------------------------------
# 5. Fail2ban
# --------------------------------------------------------------------------
banner "Configuring fail2ban"

cat > /etc/fail2ban/jail.d/aidome-sshd.local <<EOF
[sshd]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
logpath  = %(sshd_log)s
backend  = systemd
maxretry = 5
bantime  = 3600
findtime = 600

[DEFAULT]
destemail = root@localhost
sender = fail2ban@${DISPLAY_HOSTNAME}
action = %(action_)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban || warn "fail2ban restart failed"
log "Fail2ban configured"

# --------------------------------------------------------------------------
# 6. Auditd (CIS 4.1.x)
# --------------------------------------------------------------------------
banner "Configuring auditd"

cat > /etc/audit/rules.d/99-aidome-cis.rules <<'AUDITRULES'
## CIS Ubuntu Linux 24.04 LTS Benchmark — Section 4.1 Audit Rules
## Generated by AIdome bootstrap script; do not edit by hand.

# Remove all existing rules
-D

# Set buffer size large enough to avoid lost events at boot
-b 8192

# Failure mode: 1=silent (log failure), 2=panic (kernel panic on overflow)
-f 1

# 4.1.2 — System date and time modification (clock manipulation is a log-tampering prerequisite)
-a always,exit -F arch=b64 -S adjtimex -k time_change
-a always,exit -F arch=b64 -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
-w /etc/localtime -p wa -k time_change

# 4.1.3 — Identity and credential management
-w /etc/group   -p wa -k identity
-w /etc/passwd  -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow  -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# 4.1.4 — Login/logout events
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins

# 4.1.5 — Privileged command usage (setuid/setgid binaries)
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k setuid
-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k setgid

# 4.1.7 — File system modifications (delete, rename, chmod, chown)
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -k perm_mod
-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -k perm_mod
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -k delete

# 4.1.11 — Sudo/su usage and sudoers changes
-w /etc/sudoers      -p wa -k sudoers
-w /etc/sudoers.d/   -p wa -k sudoers
-w /usr/bin/sudo     -p x  -k priv_esc
-w /usr/bin/su       -p x  -k priv_esc

# 4.1.15 — SSH authorized_keys changes
-w /home/aidome-ops/.ssh -p wa -k authorized_keys

# 4.1.6 — Network socket creation (IPv4 AF_INET=2, IPv6 AF_INET6=10)
-a always,exit -F arch=b64 -S socket -F a0=2  -k network_socket_created
-a always,exit -F arch=b64 -S socket -F a0=10 -k network_socket_created

# 4.1.17 — Kernel module loading/unloading
-w /sbin/insmod  -p x -k kernel_modules
-w /sbin/rmmod   -p x -k kernel_modules
-w /sbin/modprobe -p x -k kernel_modules
-a always,exit -F arch=b64 -S init_module,delete_module -k kernel_modules

# Make the configuration immutable — requires reboot to change rules
-e 2
AUDITRULES

systemctl enable --now auditd || warn "auditd failed to start"
augenrules --load 2>/dev/null \
  || auditctl -R /etc/audit/rules.d/99-aidome-cis.rules 2>/dev/null \
  || warn "Audit rules failed to load; run: systemctl status auditd && auditctl -l"
log "Auditd configured with CIS 4.1.x rules"

# --------------------------------------------------------------------------
# 7. Disable UFW (iptables-persistent manages the firewall directly)
# --------------------------------------------------------------------------
banner "Configuring firewall"

systemctl disable ufw --now 2>/dev/null || true

mkdir -p /etc/iptables

# IPv4 rules
cat > /etc/iptables/rules.v4 <<EOF
# Host-level defense-in-depth (VMware NSX or port group ACLs are the primary perimeter).
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:DOCKER-USER - [0:0]

# Allow loopback and established/related
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

-A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# SSH on port ${SSH_PORT} — restricted to management CIDR (private network only)
-A INPUT -p tcp -s ${ALLOWED_SSH_CIDR} --dport ${SSH_PORT} -m conntrack --ctstate NEW -j ACCEPT

# HTTPS from ANY source — port 443 is the customer-facing interface
-A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

# DOCKER-USER chain — Docker forwards traffic through FORWARD, not INPUT.
# Rules here apply to container-published ports before Docker's own rules.
# (see https://docs.docker.com/engine/network/firewall-iptables/)
# Allow any source to reach containers on port 443 (customer-facing).
# Restrict all other container ports to RFC1918 private sources.
-A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
-A DOCKER-USER -p tcp -m conntrack --ctorigdstport 443 --ctdir ORIGINAL -j RETURN
-A DOCKER-USER -s 10.0.0.0/8 -j RETURN
-A DOCKER-USER -s 172.16.0.0/12 -j RETURN
-A DOCKER-USER -s 192.168.0.0/16 -j RETURN
-A DOCKER-USER -j DROP

COMMIT
EOF

# IPv6 rules
cat > /etc/iptables/rules.v6 <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback and established/related
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH over IPv6 — restricted to link-local and ULA (private networks)
-A INPUT -s fe80::/10 -p tcp --dport ${SSH_PORT} -j ACCEPT
-A INPUT -s fc00::/7 -p tcp --dport ${SSH_PORT} -j ACCEPT

# HTTPS over IPv6 from ANY source — customer-facing
-A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

COMMIT
EOF

netfilter-persistent reload || warn "netfilter-persistent reload failed; verify with: iptables -L -n"
systemctl enable netfilter-persistent || true
log "Firewall rules loaded and persisted"

# --------------------------------------------------------------------------
# 8. Install Docker Engine (official APT repository, GPG-verified)
# --------------------------------------------------------------------------
banner "Installing Docker Engine"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" -o /tmp/docker-gpg-key.asc

# Verify Docker GPG key fingerprint before trusting it
ACTUAL_FPR=$(gpg --show-keys --with-colons --fingerprint /tmp/docker-gpg-key.asc \
  | awk -F: '/^fpr:/ { print $10; exit }')
if [[ "$ACTUAL_FPR" != "$DOCKER_GPG_FINGERPRINT" ]]; then
  error "Docker GPG key fingerprint mismatch!"
  error "Expected: $DOCKER_GPG_FINGERPRINT"
  error "Got:      $ACTUAL_FPR"
  error "Aborting Docker installation."
  exit 1
fi

gpg --dearmor < /tmp/docker-gpg-key.asc > /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
rm -f /tmp/docker-gpg-key.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin \
  || { error "Docker installation failed"; exit 1; }

systemctl enable --now docker.service docker.socket || true
docker --version || true
log "Docker Engine installed"

# Add operator to docker group
usermod -aG docker "$OPERATOR_USER" 2>/dev/null || true
log "$OPERATOR_USER added to docker group"

# --------------------------------------------------------------------------
# 9. Ensure open-vm-tools is running
# --------------------------------------------------------------------------
banner "Enabling open-vm-tools"
systemctl enable --now open-vm-tools || warn "open-vm-tools failed to start"

# --------------------------------------------------------------------------
# 10. Cleanup
# --------------------------------------------------------------------------
apt-get clean || true
rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* 2>/dev/null || true

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
banner "Bootstrap Summary"
echo "Hostname:      $(hostname)"
echo "Docker:        $(systemctl is-active docker 2>/dev/null || echo 'not running')"
echo "Fail2ban:      $(systemctl is-active fail2ban 2>/dev/null || echo 'not running')"
echo "Auditd:        $(systemctl is-active auditd 2>/dev/null || echo 'not running')"
echo "Firewall:      $(iptables -L INPUT -n 2>/dev/null | head -1 || echo 'not loaded')"
echo "VMware Tools:  $(vmware-toolbox-cmd -v 2>/dev/null || echo 'not available')"
echo "End time:      $(date -u)"

log "Bootstrap completed. Instance is ready."
log "Connect via SSH as $OPERATOR_USER, then run the AIdome installer"
log "(obtain the URL from your AIdome account or support team)."

# --------------------------------------------------------------------------
# Reboot (optional)
# --------------------------------------------------------------------------
if [[ "$DO_REBOOT" == "true" ]]; then
  log "Rebooting in 5 seconds to apply kernel/network settings..."
  sleep 5
  reboot
fi
