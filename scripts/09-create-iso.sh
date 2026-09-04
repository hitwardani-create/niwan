#!/usr/bin/env bash
# ==============================================================================
# Script 09: Live ISO Generation (Squashfs + Hybrid UEFI/BIOS ISO)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${ROOT_DIR}/distro.conf"

echo "=================================================="
echo "      Generating ${DISTRO_NAME} Live ISO          "
echo "=================================================="

# Ensure directories are clean
sudo rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/live"
mkdir -p "${ISO_DIR}/boot/grub"
mkdir -p "${OUTPUT_DIR}"

# 1. Extract Kernel and Initramfs
echo "[*] Extracting Kernel and Initramfs from rootfs..."
KERNEL_FILE=$(ls -t "${ROOTFS_DIR}/boot"/vmlinuz* 2>/dev/null | head -n 1)
INITRD_FILE=$(ls -t "${ROOTFS_DIR}/boot"/initrd.img* 2>/dev/null | head -n 1)

if [ -z "${KERNEL_FILE}" ] || [ -z "${INITRD_FILE}" ]; then
    echo "[-] Error: Kernel or Initrd not found in rootfs /boot!"
    exit 1
fi

sudo cp "${KERNEL_FILE}" "${ISO_DIR}/live/vmlinuz"
sudo cp "${INITRD_FILE}" "${ISO_DIR}/live/initrd.img"

# 2. Compress Rootfs into SquashFS (zstd for fast decompression)
echo "[*] Compressing rootfs into SquashFS (using zstd)..."
sudo rm -f "${ISO_DIR}/live/filesystem.squashfs"
sudo mksquashfs "${ROOTFS_DIR}" "${ISO_DIR}/live/filesystem.squashfs" \
    -comp zstd \
    -Xcompression-level 15 \
    -b 1048576 \
    -noappend \
    -e boot

# 3. Create GRUB Configuration (UEFI and BIOS)
echo "[*] Creating GRUB bootloader configuration..."
cat <<'GRUBCFG_EOF' | sudo tee "${ISO_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=5

insmod font
if loadfont /boot/grub/font.pf2 ; then
    insmod gfxterm
    set gfxmode=auto
    terminal_output gfxterm
fi

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Start ApexOS 1.0 (Live KDE Plasma Wayland)" {
    linux /live/vmlinuz boot=live components quiet splash loglevel=3 apparmor=1 security=apparmor systemd.unified_cgroup_hierarchy=1
    initrd /live/initrd.img
}

menuentry "Start ApexOS 1.0 (Safe Graphics / Fallback Mode)" {
    linux /live/vmlinuz boot=live components nomodeset quiet splash
    initrd /live/initrd.img
}

menuentry "Memory Diagnostic (Memtest86+)" {
    linux16 /live/memtest86+.bin
}
GRUBCFG_EOF

# 4. Prepare EFI System Partition
echo "[*] Creating EFI Boot Image..."
mkdir -p "${ISO_DIR}/EFI/BOOT"
mkdir -p /tmp/apex_efi_mount

dd if=/dev/zero of="${ISO_DIR}/EFI/efiboot.img" bs=1M count=20 status=none
mkfs.vfat "${ISO_DIR}/EFI/efiboot.img" > /dev/null

sudo mount "${ISO_DIR}/EFI/efiboot.img" /tmp/apex_efi_mount
sudo mkdir -p /tmp/apex_efi_mount/EFI/BOOT

# Install GRUB EFI binary if available
if [ -f /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ]; then
    sudo cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi /tmp/apex_efi_mount/EFI/BOOT/BOOTX64.EFI
elif command -v grub-mkstandalone &>/dev/null; then
    sudo grub-mkstandalone -O x86_64-efi -o /tmp/apex_efi_mount/EFI/BOOT/BOOTX64.EFI "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"
fi

sudo cp "${ISO_DIR}/boot/grub/grub.cfg" /tmp/apex_efi_mount/EFI/BOOT/grub.cfg 2>/dev/null || true
sudo umount /tmp/apex_efi_mount
rm -rf /tmp/apex_efi_mount

# Copy BOOTX64.EFI to ISO structure as well
if [ -f /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ]; then
    sudo cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"
fi

# 5. Build Hybrid ISO using xorriso
echo "[*] Packaging Hybrid ISO with xorriso..."
ISO_OUTPUT_PATH="${OUTPUT_DIR}/${ISO_FILENAME}"

if [ -f /usr/lib/ISOLINUX/isohdpfx.bin ]; then
    MBR_OPT="-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin"
else
    MBR_OPT=""
fi

sudo xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${DISTRO_NAME^^}" \
    -eltorito-alt-boot \
    -e EFI/efiboot.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "${ISO_OUTPUT_PATH}" \
    "${ISO_DIR}"

echo "[*] Calculating SHA256 checksum..."
sha256sum "${ISO_OUTPUT_PATH}" | tee "${ISO_OUTPUT_PATH}.sha256"

echo "=================================================="
echo "[+] SUCCESS! ApexOS ISO generated at:"
echo "    ${ISO_OUTPUT_PATH}"
echo "=================================================="
