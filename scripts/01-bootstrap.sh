#!/usr/bin/env bash
# ==============================================================================
# Script 01: Debootstrap Base System
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Initializing build directories..."
mkdir -p "${ROOTFS_DIR}" "${ISO_DIR}" "${OUTPUT_DIR}"

if [ -f "${ROOTFS_DIR}/etc/debian_version" ]; then
    echo "[+] Rootfs already bootstrapped at ${ROOTFS_DIR}. Skipping debootstrap."
    exit 0
fi

echo "[*] Debootstrapping Debian ${DEBIAN_CODENAME} (${DISTRO_ARCH}) from ${DEBIAN_MIRROR}..."
sudo debootstrap \
    --arch="${DISTRO_ARCH}" \
    --components=main,contrib,non-free,non-free-firmware \
    --include=ca-certificates,gnupg,apt-transport-https \
    "${DEBIAN_CODENAME}" \
    "${ROOTFS_DIR}" \
    "${DEBIAN_MIRROR}"

echo "[*] Configuring APT repositories in rootfs..."
cat <<EOF | sudo tee "${ROOTFS_DIR}/etc/apt/sources.list"
# Debian ${DEBIAN_CODENAME} Main Repositories
deb ${DEBIAN_MIRROR} ${DEBIAN_CODENAME} main contrib non-free non-free-firmware
deb-src ${DEBIAN_MIRROR} ${DEBIAN_CODENAME} main contrib non-free non-free-firmware

# Debian Security Updates
deb ${SECURITY_MIRROR} ${DEBIAN_CODENAME}-security main contrib non-free non-free-firmware
deb-src ${SECURITY_MIRROR} ${DEBIAN_CODENAME}-security main contrib non-free non-free-firmware
EOF

echo "[+] Debootstrap phase completed successfully!"
