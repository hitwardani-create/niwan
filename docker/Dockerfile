FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    debootstrap \
    xorriso \
    squashfs-tools \
    dosfstools \
    git \
    curl \
    wget \
    tar \
    zstd \
    syslinux \
    syslinux-utils \
    isolinux \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    sudo \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["/bin/bash"]
