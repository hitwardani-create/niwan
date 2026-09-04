#!/usr/bin/env bash
# ==============================================================================
# Script 03: Install Packages into Rootfs
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Preparing package lists..."

COMBINED_PKGS=()

read_pkgs() {
    local file="$1"
    if [ -f "${file}" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line="$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [ -n "$line" ]; then
                COMBINED_PKGS+=("$line")
            fi
        done < "${file}"
    fi
}

read_pkgs "${ROOT_DIR}/config/packages/base.list"
read_pkgs "${ROOT_DIR}/config/packages/hardware.list"
read_pkgs "${ROOT_DIR}/config/packages/desktop.list"
read_pkgs "${ROOT_DIR}/config/packages/compute.list"
read_pkgs "${ROOT_DIR}/config/packages/installer.list"

echo "[*] Total packages queued for installation: ${#COMBINED_PKGS[@]}"

# Copy list into chroot for apt installation
PKGLIST_FILE="${ROOTFS_DIR}/tmp/packages.to_install"
printf "%s\n" "${COMBINED_PKGS[@]}" | sudo tee "${PKGLIST_FILE}" > /dev/null

sudo chroot "${ROOTFS_DIR}" /bin/bash <<EOF
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[*] Updating package repositories..."
apt-get update -y

echo "[*] Generating locales..."
apt-get install -y locales
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

echo "[*] Validating queued packages against repository index..."
VALID_PKGS=()
SKIPPED_PKGS=()

while IFS= read -r pkg || [ -n "\$pkg" ]; do
    [ -z "\$pkg" ] && continue
    if apt-cache show "\$pkg" >/dev/null 2>&1; then
        VALID_PKGS+=("\$pkg")
    else
        SKIPPED_PKGS+=("\$pkg")
    fi
done < /tmp/packages.to_install

if [ \${#SKIPPED_PKGS[@]} -gt 0 ]; then
    echo "[!] Note: The following packages are not present in this Debian branch and will be skipped:"
    printf '    - %s\n' "\${SKIPPED_PKGS[@]}"
fi

echo "[*] Installing \${#VALID_PKGS[@]} validated packages (this may take several minutes)..."
apt-get install -y --no-install-recommends "\${VALID_PKGS[@]}"

rm -f /tmp/packages.to_install
EOF

echo "[+] Package installation complete!"
