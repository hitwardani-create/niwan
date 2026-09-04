#!/usr/bin/env bash
# ==============================================================================
# Script 00: Check and Install Host Build Dependencies
# ==============================================================================
set -euo pipefail

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

REQUIRED_COMMANDS=(
    debootstrap
    xorriso
    mksquashfs
    mkfs.vfat
    grub-mkrescue
    git
    curl
    tar
    zstd
)

MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
        MISSING_COMMANDS+=("${cmd}")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
    echo "[-] Missing required build tools: ${MISSING_COMMANDS[*]}"
    if [ -f /etc/debian_version ] || [ -f /etc/os-release ]; then
        echo "[*] Detected Debian/Ubuntu family host. Attempting installation..."
        sudo apt-get update -y
        sudo apt-get install -y \
            debootstrap \
            xorriso \
            squashfs-tools \
            dosfstools \
            mksquashfs \
            git \
            curl \
            tar \
            zstd \
            syslinux \
            syslinux-utils \
            isolinux \
            grub-pc-bin \
            grub-efi-amd64-bin \
            mtools
        echo "[+] Host dependencies installed successfully!"
    else
        echo "[!] Please install the missing tools using your system package manager."
        exit 1
    fi
else
    echo "[+] All host build dependencies are satisfied."
fi
