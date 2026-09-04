#!/usr/bin/env bash
# ==============================================================================
# Script 04: Kernel Installation & Performance Optimization
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Setting up Kernel (${KERNEL_FLAVOR}) and Performance Tweaks..."

# Copy sysctl performance configurations
sudo cp "${ROOT_DIR}/config/sysctl.d/99-performance.conf" "${ROOTFS_DIR}/etc/sysctl.d/99-performance.conf"

# Copy zram configuration
if [ "${ENABLE_ZRAM}" = true ]; then
    echo "[*] Configuring zram-tools with ${ZRAM_COMPRESSION_ALGO}..."
    sudo cp "${ROOT_DIR}/config/systemd/zram.conf" "${ROOTFS_DIR}/etc/default/zramswap"
fi

sudo chroot "${ROOTFS_DIR}" /bin/bash <<EOF
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Install Kernel
case "${KERNEL_FLAVOR}" in
    xanmod)
        echo "[*] Adding XanMod high-performance kernel repository..."
        wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg --yes
        echo 'deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list
        apt-get update -y
        # Try modern x86-64-v3 (AVX2/FMA), fallback to generic x64 if needed
        apt-get install -y linux-xanmod-x64v3 || apt-get install -y linux-xanmod || apt-get install -y linux-image-amd64
        ;;
    liquorix)
        echo "[*] Adding Liquorix kernel repository..."
        curl -s 'https://liquorix.net/add-liquorix-repo.sh' | bash
        apt-get update -y
        apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 || apt-get install -y linux-image-amd64
        ;;
    debian|*)
        echo "[*] Installing official Debian kernel..."
        apt-get install -y linux-image-amd64 linux-headers-amd64
        ;;
esac

# 2. Enable Services
if [ "${ENABLE_ZRAM}" = true ]; then
    systemctl enable zramswap.service || true
fi

if [ "${ENABLE_ANANICY_CPP}" = true ]; then
    echo "[*] Enabling ananicy-cpp auto-nice scheduler..."
    systemctl enable ananicy-cpp.service || true
fi

# 3. Ensure PipeWire user services are active for audio
systemctl --global enable pipewire.socket || true
systemctl --global enable pipewire-pulse.socket || true
systemctl --global enable wireplumber.service || true

# 4. Power profiles daemon
systemctl enable power-profiles-daemon.service || true
EOF

echo "[+] Kernel and system performance configuration complete!"
