#!/bin/bash

echo "🔧 Software Packages Installer"

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
    
    # Communication Tools
    telegram-desktop    # Official Telegram messaging client with desktop features
    thunderbird        # Full-featured email client with calendar and chat integration

    # File Sharing & Transfer
    localsend          # Open-source alternative to AirDrop for local file transfers
    qbittorrent       # Free and open-source BitTorrent client with good privacy features

    # Media Players & Browsers
    mediainfo-gui      # Graphical interface for displaying technical media file information
    zen-browser        # Minimalist web browser based on Firefox technology
    jellyfin-media-player # Client for Jellyfin media server with playback support

    # Productivity & Office
    obsidian           # Powerful knowledge base with markdown support and graph view
    okular             # Universal document viewer (PDF, EPUB, images, etc.)
    libreoffice-fresh  # Complete office suite with word processor, spreadsheet, presentations

    # Graphics & Design
    krita              # Professional digital painting and image editing software
    gimp               # GNU Image Manipulation Program (advanced photo editing)
    blender            # Full 3D creation suite for modeling, animation, and rendering
    freecad            # Parametric 3D CAD modeler for mechanical engineering
    kicad              # Electronics design automation (EDA) software suite

    # Video Production
    kdenlive           # Non-linear video editor with multi-track editing capabilities
    handbrake          # Video transcoder for converting media to various formats
    obs-studio         # Screen recording and live streaming software

    # Hardware Control
    openrgb-git              # RGB lighting control that works across many brands/devices
    openrgb-plugin-effects-git # Additional lighting effects for OpenRGB
)

# Arrays for tracking status
installed=()
to_install=()

# Check installed packages
echo
echo "🔍 Checking installed packages..."

for pkg in "${install_buffer[@]}"; do
    if pacman -Qi "$pkg" > /dev/null 2>&1; then
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