#!/usr/bin/env bash
# ==============================================================================
# Script 07: Calamares Installer Configuration
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Configuring Calamares installer for ${DISTRO_NAME}..."

CALAMARES_TARGET="${ROOTFS_DIR}/etc/calamares"
sudo mkdir -p "${CALAMARES_TARGET}/branding/niwan"
sudo mkdir -p "${CALAMARES_TARGET}/modules"

# Copy settings and branding
sudo cp "${ROOT_DIR}/config/calamares/settings.conf" "${CALAMARES_TARGET}/settings.conf"
sudo cp "${ROOT_DIR}/config/calamares/branding/niwan/branding.desc" "${CALAMARES_TARGET}/branding/niwan/branding.desc"
sudo cp "${ROOT_DIR}/config/calamares/modules/partition.conf" "${CALAMARES_TARGET}/modules/partition.conf"

# Post-install script module to remove live packages from installed target
cat <<'POSTINSTALL_EOF' | sudo tee "${CALAMARES_TARGET}/modules/post-install.conf"
---
dontChroot: false
timeout: 120
script:
    - "-rm -f /etc/sudoers.d/99-live-user"
    - "-rm -f /etc/sddm.conf.d/autologin.conf"
    - "-userdel -r niwan"
    - "-apt-get purge -y live-boot live-config calamares"
POSTINSTALL_EOF

echo "[+] Calamares setup complete!"
