#!/bin/bash

echo "🔧 Base Packages Installer"
echo "==========================="

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "🚫 This script should not be run as root. It will use sudo when needed."
    exit 1
fi

# Define categories and packages
declare -A categories
categories=(
    ["System Information & Monitoring"]="fastfetch btop mission-center s-tui"
    ["GPU Tools"]="nvtop lact"
    ["Disk Utilities"]="filelight gnome-disk-utility"
    ["Network & Connectivity"]="networkmanager-openvpn bluez bluez-utils"
    ["Compression Tools"]="unzip zip p7zip unrar xz tar gzip bzip2 lrzip lz4 zstd"
    ["File Management"]="tree"
    ["Documentation"]="tldr man"
    ["Graphics & Display"]="gwenview"
    ["Music and Video"]="amberol mpv"
    ["Power Management"]="power-profiles-daemon"
    ["Fonts"]="noto-fonts-cjk ttf-firacode-nerd"
    ["KDE Configuration"]="konsave"
)

# Package descriptions
declare -A descriptions=(
    # System Information
    ["fastfetch"]="Lightweight system information tool that displays OS/hardware info"
    ["btop"]="Beautiful, resource-efficient terminal process monitor"
    ["mission-center"]="System monitoring tool with detailed hardware statistics"
    ["s-tui"]="Terminal-based stress test and monitoring utility"
    
    # GPU Tools
    ["nvtop"]="GPU process monitoring (NVIDIA/AMD/Intel)"
    ["lact"]="Linux AMDGPU Controller for managing AMD GPU settings"
    
    # Disk Utilities
    ["filelight"]="Disk usage analyzer with interactive pie charts"
    ["gnome-disk-utility"]="GUI for disk management and S.M.A.R.T. monitoring"
    
    # Network
    ["networkmanager-openvpn"]="OpenVPN plugin for NetworkManager"
    ["bluez"]="Official Linux Bluetooth stack"
    ["bluez-utils"]="Bluetooth utilities including bluetoothctl"
    
    # Compression
    ["unzip"]="Extraction utility for ZIP archives"
    ["zip"]="Compression utility for ZIP archives"
    ["p7zip"]="High compression ratio utility (7z format)"
    ["unrar"]="Utility for extracting RAR archives"
    ["xz"]="Compression using LZMA/LZMA2 algorithm"
    ["tar"]="Classic tape archive utility"
    ["gzip"]="Standard GNU compression utility"
    ["bzip2"]="Compression using Burrows-Wheeler algorithm"
    ["lrzip"]="Multi-threaded compression for large files"
    ["lz4"]="Extremely fast compression algorithm"
    ["zstd"]="Modern compression algorithm (good speed/ratio)"
    
    # File Management
    ["tree"]="Recursive directory listing in tree format"
    
    # Documentation
    ["tldr"]="Simplified man pages with practical examples"
    ["man"]="Traditional Unix manual pages"
    
    # Graphics
    ["gwenview"]="Fast and versatile KDE image viewer"
    
    # Music and Video
    ["amberol"]="Modern offline music player"
    ["mpv"]="Video player"
    
    # Power Management
    ["power-profiles-daemon"]="System service for managing power modes"
    
    # Fonts
    ["noto-fonts-cjk"]="Google Noto fonts with CJK support"
    ["ttf-firacode-nerd"]="Programming font with ligatures/Nerd Font symbols"
    
    # KDE Configuration
    ["konsave"]="Save and restore KDE Plasma configurations"
)

# Function to check if package is installed
is_installed() {
    pacman -Qi "$1" &>/dev/null
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
    echo "  [r] Reverse selections (select/deselect all)"
    echo "  [x] Uninstall all selected packages (danger!)"
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
        r|R)
            # Reverse selections (select/deselect all available packages)
            for i in "${!selections[@]}"; do
                if [[ "${selections[$i]}" == "available" ]]; then
                    selections[$i]="selected"
                elif [[ "${selections[$i]}" == "selected" ]]; then
                    selections[$i]="available"
                fi
                # installed packages remain unchanged
            done
            echo "🔄 Selections reversed"
            sleep 1
            ;;
        x|X)
            # Uninstall all selected packages
            echo
            echo "⚠️  DANGER: You are about to uninstall packages!"
            
            # Collect packages to uninstall (selected ones that are installed)
            to_uninstall=()
            for i in "${!selections[@]}"; do
                if [[ "${selections[$i]}" == "selected" ]] && is_installed "${all_packages[$i]}"; then
                    to_uninstall+=("${all_packages[$i]}")
                fi
            done
            
            if [ ${#to_uninstall[@]} -eq 0 ]; then
                echo "ℹ️  No installed packages are currently selected for uninstall."
                echo "Press any key to continue..."
                read -n 1
                continue
            fi
            
            echo
            echo "📦 The following packages will be REMOVED:"
            printf ' - %s\n' "${to_uninstall[@]}"
            echo
            read -p "Are you ABSOLUTELY SURE? This cannot be undone! (type 'yes' to confirm): " confirm
            echo
            
            if [[ "$confirm" == "yes" ]]; then
                echo "🗑️  Uninstalling packages..."
                uninstall_success=()
                uninstall_failed=()
                
                for pkg in "${to_uninstall[@]}"; do
                    echo "➡️ Removing $pkg..."
                    if sudo pacman -Rns --noconfirm "$pkg"; then
                        echo "✅ $pkg uninstalled successfully."
                        uninstall_success+=("$pkg")
                        # Update selection status
                        for i in "${!all_packages[@]}"; do
                            if [[ "${all_packages[$i]}" == "$pkg" ]]; then
                                selections[$i]="available"
                                break
                            fi
                        done
                    else
                        echo "❌ Failed to uninstall $pkg."
                        uninstall_failed+=("$pkg")
                    fi
                    echo
                done
                
                # Show uninstall summary
                echo
                echo "📊 Uninstall Summary"
                echo "===================="
                if [ ${#uninstall_success[@]} -gt 0 ]; then
                    echo "✅ Successfully uninstalled:"
                    printf ' - %s\n' "${uninstall_success[@]}"
                fi
                if [ ${#uninstall_failed[@]} -gt 0 ]; then
                    echo "❌ Failed to uninstall:"
                    printf ' - %s\n' "${uninstall_failed[@]}"
                fi
                echo
                echo "Press any key to return to menu..."
                read -n 1
            else
                echo "❌ Uninstall cancelled."
                sleep 1
            fi
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
                        # Allow toggling installed packages for uninstall
                        selections[$index]="selected"
                        echo "⚠️  Marked for uninstall: ${all_packages[$index]}"
                    fi
                    sleep 1
                else
                    echo "❌ Invalid number. Please enter 1-${#all_packages[@]}"
                    sleep 1
                fi
            else
                echo "❌ Invalid option. Please enter a number, a, u, c, r, x, or d"
                sleep 1
            fi
            ;;
    esac
done

# Collect selected packages for installation (excluding already installed ones)
selected_for_install=()
selected_for_uninstall=()

for i in "${!selections[@]}"; do
    pkg="${all_packages[$i]}"
    status="${selections[$i]}"
    
    if [[ "$status" == "selected" ]]; then
        if is_installed "$pkg"; then
            selected_for_uninstall+=("$pkg")
        else
            selected_for_install+=("$pkg")
        fi
    fi
done

# Handle uninstall first if any packages are marked for uninstall
if [ ${#selected_for_uninstall[@]} -gt 0 ]; then
    echo
    echo "⚠️  The following installed packages are marked for UNINSTALL:"
    printf ' - %s\n' "${selected_for_uninstall[@]}"
    echo
    read -p "Do you want to uninstall these packages before installing? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Uninstalling packages..."
        for pkg in "${selected_for_uninstall[@]}"; do
            echo "➡️ Removing $pkg..."
            if sudo pacman -Rns --noconfirm "$pkg"; then
                echo "✅ $pkg uninstalled successfully."
            else
                echo "❌ Failed to uninstall $pkg."
            fi
            echo
        done
    else
        echo "❌ Uninstall skipped. These packages will remain installed."
    fi
fi

# Proceed with installation if there are packages to install
if [ ${#selected_for_install[@]} -eq 0 ]; then
    echo "❌ No new packages selected for installation. Exiting."
    exit 0
fi

echo
echo "📦 Packages to install:"
printf ' - %s\n' "${selected_for_install[@]}"
echo

read -p "Proceed with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Update system
echo
echo "🔄 Starting system update..."
sudo pacman -Syyu --noconfirm

# Arrays to track installation results
successfully_installed=()
failed_installs=()

# Install packages
echo
echo "⬇️ Installing selected packages..."
for pkg in "${selected_for_install[@]}"; do
    echo "➡️ Installing $pkg..."
    if sudo pacman -S --noconfirm "$pkg"; then
        echo "✅ $pkg installed successfully."
        successfully_installed+=("$pkg")
    else
        echo "❌ Failed to install $pkg."
        failed_installs+=("$pkg")
    fi
    echo
done

# Final summary
echo
echo "📊 Installation Summary"
echo "======================"

if [ ${#successfully_installed[@]} -gt 0 ]; then
    echo "✅ Successfully installed:"
    printf ' - %s\n' "${successfully_installed[@]}"
    echo
fi

if [ ${#failed_installs[@]} -gt 0 ]; then
    echo "❌ Failed to install:"
    printf ' - %s\n' "${failed_installs[@]}"
    echo
fi

# Overall status
if [ ${#failed_installs[@]} -eq 0 ]; then
    echo "🎉 All packages installed successfully!"
else
    echo "⚠️  Installation completed with ${#failed_installs[@]} failure(s)."
    exit 1
fi

echo
echo "✨ All operations completed!"