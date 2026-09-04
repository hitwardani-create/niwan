#!/usr/bin/env bash
# ==============================================================================
# Script 05: Hardware Acceleration, Compute Toolchains & llama.cpp
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "[*] Configuring Hardware Compute Stacks (Nvidia, AMD ROCm, Intel NPU, Vulkan)..."

# Refresh DNS and keyrings inside rootfs
sudo rm -f "${ROOTFS_DIR}/etc/resolv.conf"
sudo cp -L /etc/resolv.conf "${ROOTFS_DIR}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" | sudo tee "${ROOTFS_DIR}/etc/resolv.conf" > /dev/null
sudo mkdir -p "${ROOTFS_DIR}/etc/apt/keyrings"

# Copy pre-bundled Intel oneAPI keyring
if [ -f "${ROOT_DIR}/config/keys/oneapi-archive-keyring.gpg" ]; then
    sudo cp "${ROOT_DIR}/config/keys/oneapi-archive-keyring.gpg" "${ROOTFS_DIR}/etc/apt/keyrings/oneapi-archive-keyring.gpg"
fi

# Copy systemd service template for llama-server
sudo mkdir -p "${ROOTFS_DIR}/etc/systemd/system"
sudo cp "${ROOT_DIR}/config/systemd/llama-server@.service" "${ROOTFS_DIR}/etc/systemd/system/llama-server@.service"

sudo chroot "${ROOTFS_DIR}" /bin/bash <<'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# 1. Hardware Detection & Device Permissions (UDEV)
# ------------------------------------------------------------------------------
mkdir -p /etc/udev/rules.d
cat <<'UDEV_EOF' > /etc/udev/rules.d/99-niwan-compute.rules
# AMD KFD & Render nodes
KERNEL=="kfd", MODE="0666", GROUP="render"
SUBSYSTEM=="drm", KERNEL=="renderD*", MODE="0666", GROUP="render"

# Intel NPU (VPU) /dev/accel*
SUBSYSTEM=="accel", KERNEL=="accel*", MODE="0666", GROUP="render"
UDEV_EOF

# ------------------------------------------------------------------------------
# 2. Intel NPU / Lunar Lake / Meteor Lake Driver Configuration
# ------------------------------------------------------------------------------
mkdir -p /etc/modprobe.d
cat <<'MODPROBE_EOF' > /etc/modprobe.d/intel-vpu.conf
# Ensure Intel IVPU driver loads with fast autosuspend
options intel_vpu dma_mask=48
MODPROBE_EOF

# Add Intel oneAPI repository for OpenVINO / Level Zero
if [ -f /etc/apt/keyrings/oneapi-archive-keyring.gpg ]; then
    echo "deb [signed-by=/etc/apt/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" > /etc/apt/sources.list.d/oneAPI.list
fi

# ------------------------------------------------------------------------------
# 3. Nvidia Driver & CUDA Auto-Detection Tooling
# ------------------------------------------------------------------------------
cat <<'NVIDIA_HELPER' > /usr/local/bin/niwan-setup-nvidia
#!/usr/bin/env bash
set -euo pipefail
echo "[*] Detecting Nvidia GPU hardware..."
if lspci | grep -Ei 'vga|3d|display' | grep -iq nvidia; then
    echo "[+] Nvidia GPU detected!"
    echo "[*] Installing proprietary Nvidia drivers and CUDA runtime..."
    apt-get update -y
    apt-get install -y nvidia-driver firmware-misc-nonfree nvidia-cuda-dev nvidia-smi
    echo "[+] Nvidia driver installation complete. Please reboot."
else
    echo "[-] No Nvidia GPU detected on this system."
fi
NVIDIA_HELPER
chmod +x /usr/local/bin/niwan-setup-nvidia

# ------------------------------------------------------------------------------
# 4. Universal Compute Status Utility (niwan-hardware)
# ------------------------------------------------------------------------------
cat <<'HW_HELPER' > /usr/local/bin/niwan-hardware
#!/usr/bin/env bash
echo "=================================================="
echo "          Niwan Hardware Compute Status           "
echo "=================================================="
echo -e "\n[CPU / Architecture]:"
lscpu | grep -E 'Model name|Architecture|CPU max MHz|Thread'

echo -e "\n[Vulkan Compute Devices]:"
if command -v vulkaninfo &>/dev/null; then
    vulkaninfo --summary 2>/dev/null || echo "No Vulkan devices reporting."
else
    echo "vulkan-tools not found."
fi

echo -e "\n[Nvidia GPUs]:"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || echo "Nvidia GPU driver inactive."
else
    echo "Nvidia driver not loaded (Run 'sudo niwan-setup-nvidia' if you have an Nvidia GPU)."
fi

echo -e "\n[Intel NPU / Compute Accelerators]:"
if [ -d /dev/accel ]; then
    ls -l /dev/accel/
    echo "[+] Intel NPU / Acceleration device active!"
else
    echo "[-] /dev/accel not active (Intel IVPU will activate on supported Meteor/Lunar Lake CPUs)."
fi

echo "=================================================="
HW_HELPER
chmod +x /usr/local/bin/niwan-hardware

# ------------------------------------------------------------------------------
# 5. Build & Install llama.cpp Native C++ Engine (with Vulkan Backend)
# ------------------------------------------------------------------------------
echo "[*] Building llama.cpp native C++ engine..."
apt-get install -y --no-install-recommends glslc libshaderc-dev spirv-tools || true

cd /tmp
rm -rf /tmp/llama.cpp
git clone --depth 1 https://github.com/ggerganov/llama.cpp.git
cd /tmp/llama.cpp

echo "[*] Configuring CMake for llama.cpp (attempting Vulkan acceleration)..."
if cmake -B build \
    -DGGML_VULKAN=ON \
    -DGGML_AVX2=ON \
    -DGGML_FMA=ON \
    -DGGML_F16C=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -G Ninja 2>/dev/null; then
    echo "[+] Configured llama.cpp with Vulkan GPU acceleration!"
else
    echo "[!] Vulkan shader compiler not available, building with AVX2 CPU acceleration..."
    rm -rf build
    cmake -B build \
        -DGGML_AVX2=ON \
        -DGGML_FMA=ON \
        -DGGML_F16C=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -G Ninja
fi

cmake --build build --config Release -j"$(nproc)"
cmake --install build --prefix /usr/local

rm -rf /tmp/llama.cpp

# Create models directory
mkdir -p /usr/local/share/models

echo "[+] llama.cpp installed successfully to /usr/local/bin!"
CHROOT_EOF

echo "[+] Hardware compute stacks and llama.cpp setup completed!"
