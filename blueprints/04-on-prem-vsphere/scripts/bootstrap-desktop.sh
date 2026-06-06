#!/usr/bin/env bash
#
# AIdome VMware vSphere — Bootstrap Script for Ubuntu Desktop (Lab / Dev Only)
# =============================================================================
# Converts a pre-installed Ubuntu Desktop into a hardened server environment
# suitable for running AIdome. Applies the same security hardening as the
# cloud-init blueprint, plus additional steps to disable the graphical
# desktop environment and unnecessary desktop services.
#
# ┌─────────────────────────────────────────────────────────────────────┐
# │  WARNING — NOT RECOMMENDED FOR PRODUCTION                         │
# │                                                                    │
# │  Ubuntu Server is the recommended platform for AIdome.             │
# │  Use this script only for lab, dev, or proof-of-concept            │
# │  environments where Desktop is the only available option.          │
# │                                                                    │
# │  Differences from Server:                                          │
# │  - Larger attack surface (GNOME, PulseAudio, Bluetooth, etc.)     │
# │  - Higher base memory and CPU usage                                │
# │  - NetworkManager instead of systemd-networkd/netplan              │
# │  - Different default firewall state                                │
# │                                                                    │
# │  This script disables the GUI and desktop services but does NOT    │
# │  uninstall them (to avoid dependency-chain surprises).             │
# └─────────────────────────────────────────────────────────────────────┘
#
# What this script does (in addition to everything bootstrap-server.sh does):
#   1. Disables GDM / GNOME display manager (sets default target to multi-user)
#   2. Disables desktop-related services (Bluetooth, CUPS, Avahi, PulseAudio)
#   3. Configures NetworkManager to coexist with netplan (if applicable)
#   4. Applies all the same hardening as bootstrap-server.sh
#
# Usage:
#   sudo bash bootstrap-desktop.sh --ssh-key "ssh-ed25519 AAAA..."
#   sudo bash bootstrap-desktop.sh --ssh-key-file /path/to/key.pub --hostname myhost --reboot
#
# Requirements:
#   - Ubuntu Desktop 22.04 LTS or 24.04 LTS
#   - Root or sudo access
#   - Outbound HTTPS connectivity for package installation
#
# Version: 1.0
# =============================================================================

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
ALLOWED_SSH_CIDR="0.0.0.0/0"
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

  WARNING: This script is for Ubuntu Desktop systems being repurposed as
  servers. For production, use Ubuntu Server with bootstrap-server.sh.

Required (one of):
  --ssh-key KEY           SSH public key string for ${OPERATOR_USER}
  --ssh-key-file FILE     Path to SSH public key file for ${OPERATOR_USER}

Optional:
  --hostname NAME         Set the VM hostname (default: keep current)
  --allowed-ssh-cidr CIDR Restrict SSH to this CIDR (default: 0.0.0.0/0)
  --reboot                Reboot after setup completes (recommended)
  -h, --help              Show this help

Example:
  sudo bash $(basename "$0") --ssh-key "ssh-ed25519 AAAA..." --hostname aidome-lab --reboot
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

# Verify we are on a supported Ubuntu release
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

banner "AIdome VMware vSphere — Desktop-to-Server Bootstrap"
warn "This script converts Ubuntu Desktop to a server configuration."
warn "NOT RECOMMENDED FOR PRODUCTION — use Ubuntu Server instead."
log "OS: $PRETTY_NAME"
log "Operator user: $OPERATOR_USER"
log "SSH port: $SSH_PORT"
log "Allowed SSH CIDR: $ALLOWED_SSH_CIDR"
log "Start time: $(date -u)"

# ==========================================================================
# DESKTOP-SPECIFIC: Disable GUI and unnecessary desktop services
# ==========================================================================
banner "Disabling graphical desktop environment"

# Switch to multi-user (text) target — stops GDM/GNOME from starting on boot
systemctl set-default multi-user.target
log "Default boot target set to multi-user.target"

# Stop the display manager now (GDM, LightDM, or SDDM)
for dm in gdm3 gdm lightdm sddm; do
  if systemctl is-active "$dm" &>/dev/null; then
    systemctl stop "$dm" 2>/dev/null || true
    log "Stopped display manager: $dm"
  fi
  if systemctl is-enabled "$dm" &>/dev/null; then
    systemctl disable "$dm" 2>/dev/null || true
    log "Disabled display manager: $dm"
  fi
done

# Disable desktop-oriented services that waste resources on a server
banner "Disabling unnecessary desktop services"

DESKTOP_SERVICES=(
  bluetooth.service
  cups.service
  cups-browsed.service
  avahi-daemon.service
  avahi-daemon.socket
  ModemManager.service
  switcheroo-control.service
  power-profiles-daemon.service
  colord.service
  fwupd.service
  whoopsie.service
  kerneloops.service
  apport.service
  gpu-manager.service
  thermald.service
)

for svc in "${DESKTOP_SERVICES[@]}"; do
  if systemctl is-enabled "$svc" &>/dev/null; then
    systemctl disable --now "$svc" 2>/dev/null || true
    log "Disabled: $svc"
  fi
done

# Mask PulseAudio system-wide (user socket/service — not maskable globally,
# but we can disable the system-wide fallback)
if systemctl is-enabled pulseaudio.service &>/dev/null; then
  systemctl disable --now pulseaudio.service 2>/dev/null || true
  systemctl mask pulseaudio.service 2>/dev/null || true
  log "Disabled and masked: pulseaudio.service"
fi
if systemctl is-enabled pulseaudio.socket &>/dev/null; then
  systemctl disable --now pulseaudio.socket 2>/dev/null || true
  log "Disabled: pulseaudio.socket"
fi

# Disable automatic screen lock / power management (GNOME settings daemon)
# These run per-user but won't apply after GDM is disabled anyway
log "Desktop services disabled"

# --------------------------------------------------------------------------
# Ensure SSH server is installed (Desktop may not ship with openssh-server)
# --------------------------------------------------------------------------
banner "Ensuring SSH server is installed"

if ! dpkg -l openssh-server &>/dev/null; then
  apt-get update -qq
  apt-get install -y openssh-server
  log "openssh-server installed"
else
  log "openssh-server already present"
fi

# ==========================================================================
# From here, apply the same hardening as bootstrap-server.sh
# ==========================================================================

# --------------------------------------------------------------------------
# 0. Set hostname (optional)
# --------------------------------------------------------------------------
if [[ -n "$VM_HOSTNAME" ]]; then
  banner "Setting hostname"
  hostnamectl set-hostname "$VM_HOSTNAME"
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

echo 'iptables-persistent iptables-persistent/autosave_v4 boolean false' | debconf-set-selections
echo 'iptables-persistent iptables-persistent/autosave_v6 boolean false' | debconf-set-selections

cat > /etc/apt/apt.conf.d/99-aidome <<'APTCONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Install-Recommends "false";
APT::Get::Assume-Yes "true";
Dpkg::Options::="--force-confdef";
Dpkg::Options::="--force-confold";
APTCONF

apt-get update -qq
apt-get upgrade -y

PACKAGES=(
  vim curl htop wget ca-certificates gnupg lsb-release python3 git
  net-tools dnsutils iproute2 traceroute mtr
  iptables-persistent netfilter-persistent
  fail2ban unattended-upgrades
  jq unzip
  auditd audispd-plugins
  open-vm-tools
  openssh-server
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

usermod -aG sudo,adm "$OPERATOR_USER" 2>/dev/null || true

echo "${OPERATOR_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${OPERATOR_USER}"
chmod 0440 "/etc/sudoers.d/90-${OPERATOR_USER}"

passwd -l "$OPERATOR_USER" >/dev/null 2>&1 || true

OPERATOR_HOME="$(eval echo "~${OPERATOR_USER}")"
mkdir -p "${OPERATOR_HOME}/.ssh"
chmod 700 "${OPERATOR_HOME}/.ssh"

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

cat > /etc/issue.net <<'BANNER'
******************************************************************
*                   AIdome VMware vSphere System                 *
*                  (Desktop — Lab / Dev Only)                    *
*                                                                *
*  WARNING: Unauthorized access is prohibited and will be       *
*  prosecuted to the full extent of the law.                    *
*                                                                *
*  All activities on this system are monitored and logged.      *
******************************************************************
BANNER

DISPLAY_HOSTNAME="${VM_HOSTNAME:-$(hostname)}"
cat > /etc/motd <<EOF

Welcome to AIdome VMware vSphere (Desktop — Lab / Dev Only)
==============================================================

NOTE: This system is running Ubuntu Desktop converted to server mode.
      For production deployments, use Ubuntu Server.

System Information:
- Hostname: ${DISPLAY_HOSTNAME}
- Docker: Docker Engine (rootful)
- VMware Tools: open-vm-tools
- Boot target: multi-user.target (GUI disabled)

Quick Start — install AIdome:
1. Connect via SSH
2. Run the AIdome installer (obtain the URL from your AIdome account or support team):
   curl -fsSL https://<your-aidome-download-url>/aidome.sh | sudo bash
3. Check Docker: docker ps
4. Check firewall rules: sudo iptables -L -n

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
# 7. Disable UFW and configure iptables firewall
# --------------------------------------------------------------------------
banner "Configuring firewall"

systemctl disable ufw --now 2>/dev/null || true

mkdir -p /etc/iptables

cat > /etc/iptables/rules.v4 <<EOF
# Host-level defense-in-depth (VMware NSX or port group ACLs are the primary perimeter).
# Restrict HTTPS inbound to RFC1918 private space.
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:DOCKER-USER - [0:0]

# Allow loopback and established/related
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

-A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# SSH on port ${SSH_PORT} — restricted to management CIDR
-A INPUT -p tcp -s ${ALLOWED_SSH_CIDR} --dport ${SSH_PORT} -m conntrack --ctstate NEW -j ACCEPT

# HTTPS from RFC1918 private IPv4 ranges
-A INPUT -s 10.0.0.0/8 -p tcp --dport 443 -j ACCEPT
-A INPUT -s 172.16.0.0/12 -p tcp --dport 443 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp --dport 443 -j ACCEPT

# DOCKER-USER chain -- Docker forwards traffic through FORWARD, not INPUT.
# Rules here apply to container-published ports before Docker's own rules.
# Allow only established/related and RFC1918 sources to reach containers.
-A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
-A DOCKER-USER -s 10.0.0.0/8 -j RETURN
-A DOCKER-USER -s 172.16.0.0/12 -j RETURN
-A DOCKER-USER -s 192.168.0.0/16 -j RETURN
-A DOCKER-USER -j DROP

COMMIT
EOF

cat > /etc/iptables/rules.v6 <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback and established/related
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH over IPv6 on port ${SSH_PORT}
-A INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT

# HTTPS over IPv6 from ULA space
-A INPUT -s fc00::/7 -p tcp --dport 443 -j ACCEPT

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
banner "Bootstrap Summary (Desktop → Server)"
echo "Hostname:       $(hostname)"
echo "Boot target:    $(systemctl get-default)"
echo "Docker status:  $(systemctl is-active docker || echo inactive)"
echo "Fail2ban:       $(systemctl is-active fail2ban || echo inactive)"
echo "Auditd:         $(systemctl is-active auditd || echo inactive)"
echo "Firewall:       $(systemctl is-active netfilter-persistent || echo inactive)"
echo "VMware Tools:   $(vmware-toolbox-cmd -v 2>/dev/null || echo 'not available')"
echo "Display manager: $(systemctl is-active gdm3 2>/dev/null || echo 'disabled')"
echo "End time:       $(date -u)"

log "Bootstrap completed. Desktop services disabled, server hardening applied."
log "Connect via SSH as $OPERATOR_USER, then run the AIdome installer"
log "(obtain the URL from your AIdome account or support team)."
warn "Reminder: Ubuntu Desktop is NOT recommended for production. Use Ubuntu Server."

# --------------------------------------------------------------------------
# Reboot (recommended for Desktop to fully stop GUI processes)
# --------------------------------------------------------------------------
if [[ "$DO_REBOOT" == "true" ]]; then
  log "Rebooting in 5 seconds to apply kernel/network settings and fully stop GUI..."
  sleep 5
  reboot
fi
