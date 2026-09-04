#!/usr/bin/env bash
# ==============================================================================
# Script 02: Chroot Base Identity & User Configuration
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Configuring base system in chroot..."

# Mount essential virtual filesystems
sudo mount -t proc none "${ROOTFS_DIR}/proc" 2>/dev/null || true
sudo mount -t sysfs none "${ROOTFS_DIR}/sys" 2>/dev/null || true
sudo mount --bind /dev "${ROOTFS_DIR}/dev" 2>/dev/null || true
sudo mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true

# Set up nameserver inside chroot
echo "nameserver 1.1.1.1" | sudo tee "${ROOTFS_DIR}/etc/resolv.conf" > /dev/null

# Execute configuration inside chroot
sudo chroot "${ROOTFS_DIR}" /bin/bash <<EOF
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Hostname
echo "${LIVE_HOSTNAME}" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
127.0.1.1   ${LIVE_HOSTNAME}

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# Branding & OS-Release
cat <<OSRELEASE > /etc/os-release
NAME="${DISTRO_NAME}"
PRETTY_NAME="${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
ID="${DISTRO_NAME,,}"
ID_LIKE="debian"
VERSION="${DISTRO_VERSION} (${DISTRO_CODENAME})"
VERSION_ID="${DISTRO_VERSION}"
VERSION_CODENAME="${DEBIAN_CODENAME}"
HOME_URL="${DISTRO_URL}"
SUPPORT_URL="${DISTRO_URL}/issues"
BUG_REPORT_URL="${DISTRO_URL}/issues"
OSRELEASE

echo "${DISTRO_NAME} ${DISTRO_VERSION} \\n \\l" > /etc/issue
echo "${DISTRO_NAME} ${DISTRO_VERSION}" > /etc/issue.net

# Set Root Password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create Live User
if ! id -u "${LIVE_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -c "${LIVE_USER_NAME}" "${LIVE_USER}"
    echo "${LIVE_USER}:${LIVE_PASSWORD}" | chpasswd
    usermod -aG sudo,audio,video,plugdev,netdev,input "${LIVE_USER}"
fi

# Passwordless sudo for live user
mkdir -p /etc/sudoers.d
echo "${LIVE_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-live-user
chmod 0440 /etc/sudoers.d/99-live-user
EOF

echo "[+] Base identity configured successfully!"
