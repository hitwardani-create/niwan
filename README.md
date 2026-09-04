# ApexOS 🚀
> **Super-Fast, Minimal, AI-Native Debian Linux Distribution**

ApexOS is an ultra-fast, minimal, modern Linux distribution built on **Debian Testing (Trixie)**, optimized for modern PCs and laptops with out-of-the-box hardware acceleration and a native C++ AI development stack.

---

## ⚡ Key Highlights

- **Ultra-Fast Kernel & Scheduling**:
  - Choice of **XanMod Kernel** (x86-64-v3 microarchitecture optimization, BBR3 TCP, PREEMPT_RT full preemption) or Liquorix.
  - `zram-tools` with **zstd compression** (100% RAM allocation) for instantaneous swap without disk I/O latency.
  - `ananicy-cpp` auto-nice C++ daemon to keep desktop UI responsive under compile or AI workloads.
  - Optimized kernel `sysctl` parameters (`vm.swappiness=10`, `vm.dirty_ratio=10`, `bbr`).

- **Minimal, Smooth Wayland Desktop**:
  - **KDE Plasma** configured on Wayland for fluid hardware-accelerated animations.
  - Minimal footprint (< 650MB idle RAM, Akonadi/PIM bloat completely stripped).
  - Modern dark Breeze theme with JetBrains Mono developer fonts.

- **Out-of-the-Box Hardware Support**:
  - Full non-free firmware suite (Intel & AMD CPU microcodes, Intel/Realtek/Broadcom Wi-Fi & Bluetooth, SOF audio firmware).
  - **PipeWire** low-latency audio stack with WirePlumber.
  - Modern battery & thermal management via `power-profiles-daemon`.

- **C++ AI-Native Compute Stack**:
  - **Universal Vulkan Compute**: Pre-configured cross-vendor acceleration for AMD, Intel, and Nvidia.
  - **`llama.cpp` C++ Runtime**: Native binaries (`llama-cli`, `llama-server`) compiled with AVX2, FMA, F16C, and Vulkan backend.
  - **Intel NPU Support**: Pre-configured IVPU kernel modules and OpenVINO / Level Zero driver stack for Meteor Lake, Lunar Lake, and Arrow Lake.
  - **Nvidia CUDA & AMD ROCm**: Repositories, udev permissions, and automatic driver installer (`apex-setup-nvidia`).
  - Systemd service template `llama-server@.service` ready to serve models locally at port 8080.

- **Calamares Graphical Installer**:
  - Fast, graphical installation experience.
  - Formats NVMe/SSDs with **Btrfs filesystem using zstd:3 compression** by default with subvolumes (`@` and `@home`).

---

## 📁 Project Architecture

```
Development/
├── build.sh                     # Master build script (CLI entrypoint)
├── distro.conf                  # Central distribution configuration
├── .github/
│   └── workflows/
│       └── build-iso.yml        # Automated GitHub Actions ISO build & release
├── config/
│   ├── packages/                # Modular package lists
│   │   ├── base.list            # Core utilities, btrfs, network
│   │   ├── hardware.list        # Microcode, firmware, pipewire, bluetooth
│   │   ├── desktop.list         # Minimal KDE Plasma, Wayland, SDDM
│   │   ├── compute.list         # C++ toolchains, Vulkan, OpenCL
│   │   └── installer.list       # Calamares, live-boot
│   ├── calamares/               # Installer branding, layout, & Btrfs config
│   ├── sysctl.d/                # Performance kernel parameters (99-performance.conf)
│   └── systemd/                 # zram and llama-server service templates
├── docker/
│   └── Dockerfile               # Reproducible containerized build environment
└── scripts/
    ├── 00-check-deps.sh         # Validates and installs host build tools
    ├── 01-bootstrap.sh          # Debootstrap Debian Trixie base
    ├── 02-chroot-base.sh        # System identity, live user, sudoers
    ├── 03-install-packages.sh   # Installs modular package lists
    ├── 04-kernel-performance.sh # Kernel (XanMod), zram, ananicy-cpp
    ├── 05-hardware-and-compute.sh # Vulkan, NPU, Nvidia, AMD, llama.cpp
    ├── 06-desktop-kde.sh        # SDDM autologin, Wayland session, Breeze theme
    ├── 07-installer-calamares.sh # Calamares setup and cleanup hooks
    ├── 08-cleanup.sh            # Rootfs scrubbing and unmounting
    └── 09-create-iso.sh         # SquashFS creation & hybrid UEFI/BIOS ISO packaging
```

---

## 🛠️ How to Build

### Option 1: Native Local Build (Debian / Ubuntu / Pop!_OS)

Run the master build script with `sudo`:

```bash
# 1. Run complete end-to-end build
sudo ./build.sh --all
```

The final bootable ISO and SHA256 checksum will be generated under `output/`:
```bash
ls -lh output/
# apexos-1.0-alpha-amd64.iso
# apexos-1.0-alpha-amd64.iso.sha256
```

### Option 2: Isolated Docker Build

Build inside an isolated Docker container without altering your host system:

```bash
./build.sh --docker
```

### Option 3: Automated GitHub Actions CI/CD

This repository includes [`.github/workflows/build-iso.yml`](file:///.github/workflows/build-iso.yml):
1. Push this code to your GitHub repository.
2. Go to **Actions** > **Build ApexOS ISO** > **Run workflow**.
3. Download the generated ISO artifact directly from the workflow run or GitHub Releases (by pushing a tag `git tag v1.0.0 && git push origin v1.0.0`).

---

## 🧪 Testing the ISO

### Test with QEMU Virtual Machine:

```bash
./build.sh --qemu
```

### Flash to USB Drive:

```bash
sudo dd if=output/apexos-1.0-alpha-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Replace `/dev/sdX` with your USB drive identifier)*

---

## 💻 Built-in Commands in ApexOS

Once booted into ApexOS, you have access to native compute tools:

| Command | Description |
|---|---|
| `apex-hardware` | Inspect detected CPU, Vulkan GPUs, Nvidia CUDA, and Intel NPU status |
| `apex-setup-nvidia` | One-click automated installer for proprietary Nvidia drivers and CUDA |
| `llama-cli` | High-performance C++ CLI inference engine |
| `llama-server` | High-performance local OpenAI-compatible inference server |
| `systemctl --user start llama-server@$USER` | Run local AI server in background on port 8080 |

---

## ⚙️ Customization

Edit [`distro.conf`](file:///distro.conf) to tweak:
- `DISTRO_NAME` and `DISTRO_VERSION`
- `KERNEL_FLAVOR` (`xanmod`, `liquorix`, or `debian`)
- `DEBIAN_CODENAME` (`trixie` or `sid`)
- `ENABLE_LLAMACPP` and backend options (`vulkan`)
