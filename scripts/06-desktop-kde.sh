#!/usr/bin/env bash
# ==============================================================================
# Script 06: Minimal Fast KDE Plasma Wayland Configuration
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Configuring KDE Plasma Wayland desktop and SDDM..."

# Ensure SDDM directories exist
sudo mkdir -p "${ROOTFS_DIR}/etc/sddm.conf.d"

# Configure SDDM Autologin for Live Environment
cat <<EOF | sudo tee "${ROOTFS_DIR}/etc/sddm.conf.d/autologin.conf"
[Autologin]
User=${LIVE_USER}
Session=${DEFAULT_SESSION}
Relogin=false

[Theme]
Current=breeze

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
EOF

# Setup Calamares Desktop Launcher on Live Desktop
LIVE_USER_HOME="${ROOTFS_DIR}/home/${LIVE_USER}"
sudo mkdir -p "${LIVE_USER_HOME}/Desktop"

cat <<EOF | sudo tee "${LIVE_USER_HOME}/Desktop/install-apexos.desktop"
[Desktop Entry]
Type=Application
Version=1.0
Name=Install ${DISTRO_NAME}
Comment=Install ${DISTRO_NAME} ${DISTRO_VERSION} to your disk
Exec=sudo calamares -d
Icon=calamares
Terminal=false
Categories=System;
StartupNotify=true
EOF

sudo chmod +x "${LIVE_USER_HOME}/Desktop/install-apexos.desktop"

# Set up clean user settings and disable bloat in chroot
sudo chroot "${ROOTFS_DIR}" /bin/bash <<EOF
set -euo pipefail

# Enable SDDM service
systemctl enable sddm.service || true

# Set ownership of live user home
chown -R ${LIVE_USER}:${LIVE_USER} /home/${LIVE_USER}

# Mask unneeded heavy background services if installed
systemctl --global mask akonadi.service 2>/dev/null || true

# Set modern default shell for live user
chsh -s /bin/bash ${LIVE_USER}
EOF

echo "[+] KDE Plasma and SDDM configured!"
