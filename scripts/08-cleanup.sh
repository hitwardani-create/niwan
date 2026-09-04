#!/usr/bin/env bash
# ==============================================================================
# Script 08: Chroot Cleanup & Unmount
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Cleaning up chroot environment..."

sudo chroot "${ROOTFS_DIR}" /bin/bash <<'CLEANUP_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/*
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
rm -f /root/.bash_history
CLEANUP_EOF

echo "[*] Unmounting virtual filesystems from chroot..."
sudo umount -lf "${ROOTFS_DIR}/proc" 2>/dev/null || true
sudo umount -lf "${ROOTFS_DIR}/sys" 2>/dev/null || true
sudo umount -lf "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
sudo umount -lf "${ROOTFS_DIR}/dev" 2>/dev/null || true

echo "[+] Chroot cleanup completed successfully!"
