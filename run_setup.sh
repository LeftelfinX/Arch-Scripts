#!/bin/bash

echo "🔧 Base Packages Installer"

if [ "$(id -u)" -ne 0 ]; then
    echo "🚫 This script must be run as root. Use sudo or log in as root."
    exit 1
fi

# Update the system
echo
echo "🔄 Starting full system update..."
sudo pacman -Syyu

# Define the install buffer with descriptions, sorted by category
install_buffer=(
    
    # System Information & Monitoring
    fastfetch             # Lightweight system information tool that displays OS/hardware info
    btop                  # Beautiful, resource-efficient terminal process monitor
    glances               # Cross-platform system monitor with web interface
    mission-center        # System monitoring tool with detailed hardware statistics
    s-tui                 # Terminal-based stress test and monitoring utility

    # GPU Tools
    nvtop                 # GPU process monitoring (NVIDIA/AMD/Intel)
    lact                  # Linux AMDGPU Controller for managing AMD GPU settings
    opencl-amd            # AMD's OpenCL implementation for GPU acceleration

    # Cooling Control
    coolercontrol         # Advanced cooling control for GPUs/fans/liquid cooling

    # Disk Utilities
    filelight             # Disk usage analyzer with interactive pie charts
    gnome-disk-utility    # GUI for disk management and S.M.A.R.T. monitoring

    # Boot Management
    grub-customizer       # GUI tool for customizing GRUB bootloader settings

    # Network & Connectivity
    networkmanager-openvpn # OpenVPN plugin for NetworkManager
    bluez                 # Official Linux Bluetooth stack
    bluez-utils           # Bluetooth utilities including bluetoothctl

    # Compression Tools
    unzip                 # Extraction utility for ZIP archives
    zip                   # Compression utility for ZIP archives
    p7zip                 # High compression ratio utility (7z format)
    unrar                 # Utility for extracting RAR archives
    xz                    # Compression using LZMA/LZMA2 algorithm
    tar                   # Classic tape archive utility
    gzip                  # Standard GNU compression utility
    bzip2                 # Compression using Burrows-Wheeler algorithm
    lrzip                 # Multi-threaded compression for large files
    lz4                   # Extremely fast compression algorithm
    zstd                  # Modern compression algorithm (good speed/ratio)

    # File Management
    tree                  # Recursive directory listing in tree format

    # Documentation
    tldr                  # Simplified man pages with practical examples
    man                   # Traditional Unix manual pages

    # Graphics & Display
    gwenview              # Fast and versatile KDE image viewer

    # Web Browser
    firefox               # Privacy-focused, open-source web browser

    # Power Management
    power-profiles-daemon # System service for managing power modes

    # Fonts
    noto-fonts-cjk        # Google Noto fonts with CJK support
    ttf-firacode-nerd     # Programming font with ligatures/Nerd Font symbols
    
    # KDE Configuration
    konsave               # Save and restore KDE Plasma configurations
)

# Arrays for tracking status
installed=()
to_install=()

# Check installed packages
echo
echo "🔍 Checking installed packages..."

for pkg in "${install_buffer[@]}"; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
        installed+=("$pkg")
    else
        to_install+=("$pkg")
    fi
done

# Show already installed packages
if [ ${#installed[@]} -gt 0 ]; then
    echo
    echo "✅ Already installed:"
    printf ' - %s\n' "${installed[@]}"
fi

# Install missing packages
if [ ${#to_install[@]} -gt 0 ]; then
    echo
    echo "⬇️ Installing missing packages..."

    for pkg in "${to_install[@]}"; do
        echo "➡️ Installing $pkg..."
        if sudo pacman -S --noconfirm "$pkg"; then
            echo "✅ $pkg installed successfully."
        else
            echo "❌ Failed to install $pkg."
        fi
        echo
    done
else
    echo
    echo "🎉 All base packages are already installed. Nothing to install!"
fi

# Enable and start Bluetooth service
echo
echo "🔵 Setting up Bluetooth..."
if sudo systemctl enable --now bluetooth.service; then
    echo "✅ Bluetooth service enabled and started."
else
    echo "❌ Failed to enable Bluetooth service."
fi

# Enable and start CoolerControl daemon
echo
echo "❄️ Setting up CoolerControl..."
if sudo systemctl enable --now coolercontrold.service; then
    echo "✅ CoolerControl daemon enabled and started."
else
    echo "❌ Failed to enable CoolerControl daemon."
    echo "ℹ️ If coolercontrold.service doesn't exist, you may need to:"
    echo "   1. Check if coolercontrol was installed correctly"
    echo "   2. Run 'systemctl start coolercontrold' manually"
fi

echo
echo "✨ All operations completed!"