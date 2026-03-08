#!/bin/bash

echo "🔧 Software Packages Installer"
echo "=============================="

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "🚫 This script should not be run as root. It will use sudo when needed."
    exit 1
fi

# Check if yay is available (but don't install it)
check_yay() {
    if ! command -v yay &> /dev/null; then
        echo "❌ yay (AUR helper) is not installed. Please install yay first."
        echo "You can install it with:"
        echo "  git clone https://aur.archlinux.org/yay.git"
        echo "  cd yay"
        echo "  makepkg -si"
        exit 1
    fi
}

# Define categories and packages
declare -A categories
categories=(
    ["Communication Tools"]="telegram-desktop thunderbird"
    ["File Sharing & Transfer"]="localsend-bin qbittorrent"
    ["Media Players & Browsers"]="mediainfo-gui zen-browser-bin fladder-bin"
    ["Productivity & Office"]="obsidian okular libreoffice-fresh"
    ["Graphics & Design"]="krita gimp blender freecad kicad"
    ["Video Production"]="kdenlive handbrake obs-studio"
    ["Audio Creation"]="audacity"
)

# Define AUR packages
aur_packages=(
    "zen-browser-bin"
    "localsend-bin"
    "fladder-bin"
)

# Package descriptions
declare -A descriptions=(
    # Communication
    ["telegram-desktop"]="Official Telegram messaging client"
    ["thunderbird"]="Full-featured email client"
    
    # File Sharing
    ["localsend-bin"]="Open-source AirDrop alternative for local file transfers (AUR)"
    ["qbittorrent"]="Free BitTorrent client with good privacy features"
    
    # Media
    ["mediainfo-gui"]="GUI for displaying technical media information"
    ["zen-browser-bin"]="Minimalist Firefox-based web browser (AUR)"
    ["fladder-bin"]="Jellyfin media client for desktop (AUR)"
    
    # Productivity
    ["obsidian"]="Powerful knowledge base with markdown support"
    ["okular"]="Universal document viewer"
    ["libreoffice-fresh"]="Complete office suite"
    
    # Graphics
    ["krita"]="Professional digital painting software"
    ["gimp"]="GNU Image Manipulation Program"
    ["blender"]="3D creation suite"
    ["freecad"]="Parametric 3D CAD modeler"
    ["kicad"]="Electronics design automation suite"
    
    # Video
    ["kdenlive"]="Non-linear video editor"
    ["handbrake"]="Video transcoder"
    ["obs-studio"]="Screen recording and streaming software"
    
    # Audio
    ["audacity"]="Audio recorder and editor"
)

# Function to check if package is installed
is_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Function to get package status
get_status() {
    if is_installed "$1"; then
        echo "✅"
    else
        echo "⬜"
    fi
}

# Create arrays for all packages with their categories
all_packages=()
package_categories=()

for category in "${!categories[@]}"; do
    packages=(${categories[$category]})
    for pkg in "${packages[@]}"; do
        all_packages+=("$pkg")
        package_categories+=("$category")
    done
done

# Initialize selections based on installation status
selections=()
for pkg in "${all_packages[@]}"; do
    if is_installed "$pkg"; then
        selections+=("installed")
    else
        selections+=("available")
    fi
done

# Simple menu function
show_menu() {
    clear
    echo "📦 Package Selection (enter numbers to toggle, 'a' for all, 'd' when done)"
    echo "=========================================================================="
    echo
    
    current_category=""
    for i in "${!all_packages[@]}"; do
        pkg="${all_packages[$i]}"
        category="${package_categories[$i]}"
        status="${selections[$i]}"
        
        # Show category header
        if [[ "$category" != "$current_category" ]]; then
            current_category="$category"
            echo
            echo "$current_category"
            echo "-----------------"
        fi
        
        # Show package with selection
        index=$((i+1))
        if [[ "$status" == "installed" ]]; then
            echo "  [$index] ✅ $pkg (installed) - ${descriptions[$pkg]}"
        elif [[ "$status" == "selected" ]]; then
            echo "  [$index] ☑️  $pkg - ${descriptions[$pkg]}"
        else
            echo "  [$index] ⬜ $pkg - ${descriptions[$pkg]}"
        fi
    done
    
    echo
    echo "  [a] Select all available packages"
    echo "  [u] Select only uninstalled packages"
    echo "  [c] Clear all selections"
    echo "  [d] Done - proceed with installation"
    echo
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter choice: " choice
    
    case $choice in
        d|D)
            break
            ;;
        a|A)
            # Select all available packages
            for i in "${!selections[@]}"; do
                if [[ "${selections[$i]}" != "installed" ]]; then
                    selections[$i]="selected"
                fi
            done
            echo "✅ All available packages selected"
            sleep 1
            ;;
        u|U)
            # Select only uninstalled packages
            for i in "${!selections[@]}"; do
                if [[ "${selections[$i]}" == "available" ]]; then
                    selections[$i]="selected"
                fi
            done
            echo "✅ All uninstalled packages selected"
            sleep 1
            ;;
        c|C)
            # Clear selections
            for i in "${!selections[@]}"; do
                if [[ "${selections[$i]}" == "selected" ]]; then
                    selections[$i]="available"
                fi
            done
            echo "✅ Selections cleared"
            sleep 1
            ;;
        *)
            # Check if it's a number
            if [[ "$choice" =~ ^[0-9]+$ ]]; then
                index=$((choice-1))
                if [[ $index -ge 0 && $index -lt ${#all_packages[@]} ]]; then
                    if [[ "${selections[$index]}" == "available" ]]; then
                        selections[$index]="selected"
                        echo "✅ Selected: ${all_packages[$index]}"
                    elif [[ "${selections[$index]}" == "selected" ]]; then
                        selections[$index]="available"
                        echo "❌ Deselected: ${all_packages[$index]}"
                    elif [[ "${selections[$index]}" == "installed" ]]; then
                        echo "ℹ️  ${all_packages[$index]} is already installed and cannot be deselected"
                    fi
                    sleep 1
                else
                    echo "❌ Invalid number. Please enter 1-${#all_packages[@]}"
                    sleep 1
                fi
            else
                echo "❌ Invalid option. Please enter a number, a, u, c, or d"
                sleep 1
            fi
            ;;
    esac
done

# Collect selected packages (excluding already installed ones)
selected_packages=()
for i in "${!selections[@]}"; do
    if [[ "${selections[$i]}" == "selected" ]]; then
        selected_packages+=("${all_packages[$i]}")
    fi
done

if [ ${#selected_packages[@]} -eq 0 ]; then
    echo "❌ No new packages selected for installation. Exiting."
    exit 0
fi

echo
echo "📦 Packages to install:"
printf ' - %s\n' "${selected_packages[@]}"
echo

read -p "Proceed with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Check for AUR packages
aur_to_install=()
repo_to_install=()

for pkg in "${selected_packages[@]}"; do
    if [[ " ${aur_packages[@]} " =~ " ${pkg} " ]]; then
        aur_to_install+=("$pkg")
    else
        repo_to_install+=("$pkg")
    fi
done

# Check yay only if there are AUR packages to install
if [ ${#aur_to_install[@]} -gt 0 ]; then
    check_yay
fi

# Update system
echo
echo "🔄 Starting system update..."
sudo pacman -Syyu --noconfirm

# Install repository packages
if [ ${#repo_to_install[@]} -gt 0 ]; then
    echo
    echo "⬇️ Installing repository packages..."
    for pkg in "${repo_to_install[@]}"; do
        echo "➡️ Installing $pkg..."
        if sudo pacman -S --noconfirm "$pkg"; then
            echo "✅ $pkg installed successfully."
        else
            echo "❌ Failed to install $pkg."
        fi
        echo
    done
fi

# Install AUR packages
if [ ${#aur_to_install[@]} -gt 0 ]; then
    echo
    echo "⬇️ Installing AUR packages..."
    
    for pkg in "${aur_to_install[@]}"; do
        echo "➡️ Installing $pkg from AUR..."
        if yay -S --noconfirm "$pkg"; then
            echo "✅ $pkg installed successfully."
        else
            echo "❌ Failed to install $pkg."
        fi
        echo
    done
fi

# Final summary
echo
echo "📊 Installation Summary"
echo "======================"
echo "✅ Installed packages:"
printf ' - %s\n' "${selected_packages[@]}"

echo
echo "🎉 Package installation complete!"