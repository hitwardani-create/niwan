#!/usr/bin/env bash
# ==============================================================================
# Niwan Master Build Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/distro.conf"

print_banner() {
    cat <<'EOF'
    _   ___                         
   / | / (_)      ______ _____      
  /  |/ / / | /| / / __ `/ __ \     
 / /|  / /| |/ |/ / /_/ / / / /     
/_/ |_/_/ |__/|__/\__,_/_/ /_/      
       High-Performance AI-Native Debian OS
EOF
    echo "Distro: ${DISTRO_NAME} (${DISTRO_CODENAME}) v${DISTRO_VERSION}"
    echo "Target: ${DISTRO_ARCH} | Kernel: ${KERNEL_FLAVOR}"
    echo "=================================================="
}

usage() {
    echo "Usage: sudo ./build.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  --all            Run complete end-to-end build (default)"
    echo "  --deps           Check and install host build dependencies"
    echo "  --bootstrap      Run debootstrap phase only"
    echo "  --packages       Install packages & desktop environment"
    echo "  --compute        Setup compute stacks & llama.cpp"
    echo "  --iso            Package rootfs into bootable Live ISO"
    echo "  --shell          Open interactive bash shell inside chroot"
    echo "  --clean          Clean up build work directory"
    echo "  --qemu           Test generated ISO inside QEMU"
    echo "  --docker         Build inside an isolated Docker container"
    echo "  --help           Show this help message"
    exit 0
}

cleanup() {
    echo "[*] Cleaning build environment..."
    sudo umount -lf "${ROOTFS_DIR}/proc" 2>/dev/null || true
    sudo umount -lf "${ROOTFS_DIR}/sys" 2>/dev/null || true
    sudo umount -lf "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    sudo umount -lf "${ROOTFS_DIR}/dev" 2>/dev/null || true
    sudo rm -rf "${WORK_DIR}"
    echo "[+] Cleaned up ${WORK_DIR}."
}

open_shell() {
    if [ ! -d "${ROOTFS_DIR}" ]; then
        echo "[-] Rootfs does not exist at ${ROOTFS_DIR}. Run build first."
        exit 1
    fi
    echo "[*] Mounting virtual filesystems..."
    sudo mount -t proc none "${ROOTFS_DIR}/proc" 2>/dev/null || true
    sudo mount -t sysfs none "${ROOTFS_DIR}/sys" 2>/dev/null || true
    sudo mount --bind /dev "${ROOTFS_DIR}/dev" 2>/dev/null || true
    sudo mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    echo "[+] Entering chroot shell (type 'exit' to leave)..."
    sudo chroot "${ROOTFS_DIR}" /bin/bash
}

test_qemu() {
    ISO_PATH="${OUTPUT_DIR}/${ISO_FILENAME}"
    if [ ! -f "${ISO_PATH}" ]; then
        echo "[-] ISO not found at ${ISO_PATH}. Run build first!"
        exit 1
    fi
    echo "[*] Launching QEMU with UEFI support..."
    qemu-system-x86_64 \
        -enable-kvm \
        -m 4G \
        -smp 4 \
        -vga virtio \
        -display gtk,gl=on \
        -cdrom "${ISO_PATH}" \
        -boot d
}

build_docker() {
    echo "[*] Building ISO via Docker container..."
    cd "${SCRIPT_DIR}/docker"
    docker build -t niwan-builder .
    docker run --privileged --rm \
        -v "${SCRIPT_DIR}:/workspace" \
        -w /workspace \
        niwan-builder \
        ./build.sh --all
}

main() {
    print_banner

    ACTION="${1:---all}"

    case "${ACTION}" in
        --help|-h)
            usage
            ;;
        --clean)
            cleanup
            ;;
        --deps)
            "${SCRIPT_DIR}/scripts/00-check-deps.sh"
            ;;
        --shell)
            open_shell
            ;;
        --qemu)
            test_qemu
            ;;
        --docker)
            build_docker
            ;;
        --bootstrap)
            "${SCRIPT_DIR}/scripts/00-check-deps.sh"
            "${SCRIPT_DIR}/scripts/01-bootstrap.sh"
            ;;
        --packages)
            "${SCRIPT_DIR}/scripts/02-chroot-base.sh"
            "${SCRIPT_DIR}/scripts/03-install-packages.sh"
            "${SCRIPT_DIR}/scripts/04-kernel-performance.sh"
            "${SCRIPT_DIR}/scripts/06-desktop-kde.sh"
            "${SCRIPT_DIR}/scripts/07-installer-calamares.sh"
            ;;
        --compute)
            "${SCRIPT_DIR}/scripts/05-hardware-and-compute.sh"
            ;;
        --iso)
            "${SCRIPT_DIR}/scripts/08-cleanup.sh"
            "${SCRIPT_DIR}/scripts/09-create-iso.sh"
            ;;
        --all)
            echo "[*] Starting full end-to-end OS build..."
            "${SCRIPT_DIR}/scripts/00-check-deps.sh"
            "${SCRIPT_DIR}/scripts/01-bootstrap.sh"
            "${SCRIPT_DIR}/scripts/02-chroot-base.sh"
            "${SCRIPT_DIR}/scripts/03-install-packages.sh"
            "${SCRIPT_DIR}/scripts/04-kernel-performance.sh"
            "${SCRIPT_DIR}/scripts/05-hardware-and-compute.sh"
            "${SCRIPT_DIR}/scripts/06-desktop-kde.sh"
            "${SCRIPT_DIR}/scripts/07-installer-calamares.sh"
            "${SCRIPT_DIR}/scripts/08-cleanup.sh"
            "${SCRIPT_DIR}/scripts/09-create-iso.sh"
            echo "[+] Build pipeline completed successfully!"
            ;;
        *)
            echo "[-] Unknown option: ${ACTION}"
            usage
            ;;
    esac
}

main "$@"
