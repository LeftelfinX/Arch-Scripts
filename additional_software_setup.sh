#!/bin/bash

echo "🔧 Software Packages Installer/Uninstaller (AUR with yay)"
echo "========================================================="

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "🚫 This script should not be run as root. It will use sudo when needed."
    exit 1
fi

# Define categories and packages (mix of repo and AUR)
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

# Define AUR packages (these come from AUR, not official repos)
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
    pacman -Qi "$1" &>/dev/null || yay -Qi "$1" &>/dev/null
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

# Simple menu function for install mode
show_install_menu() {
    clear
    echo "📦 INSTALL MODE - Package Selection (enter numbers to toggle, 'a' for all, 'd' when done)"
    echo "=========================================================================================="
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
    echo "  [m] Switch to UNINSTALL mode"
    echo
}

# Simple menu function for uninstall mode
show_uninstall_menu() {
    clear
    echo "🗑️  UNINSTALL MODE - Package Selection (enter numbers to toggle, 'A' for all installed, 'd' when done)"
    echo "========================================================================================================"
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
        if [[ "$status" == "installed" ]] || [[ "$status" == "selected_for_uninstall" ]]; then
            if [[ "$status" == "selected_for_uninstall" ]]; then
                echo "  [$index] 🔴 $pkg (marked for removal) - ${descriptions[$pkg]}"
            else
                echo "  [$index] ✅ $pkg (installed) - ${descriptions[$pkg]}"
            fi
        else
            echo "  [$index] ⬜ $pkg (not installed) - ${descriptions[$pkg]}"
        fi
    done
    
    echo
    echo "  [A] Select ALL installed packages for removal"
    echo "  [c] Clear all selections"
    echo "  [d] Done - proceed with uninstallation"
    echo "  [m] Switch to INSTALL mode"
    echo
}

# Main menu loop for mode selection
echo "Select mode:"
echo "  1) Install packages"
echo "  2) Uninstall packages"
read -p "Enter choice (1 or 2): " mode_choice
echo

if [[ "$mode_choice" == "2" ]]; then
    # UNINSTALL MODE
    echo "🗑️  Uninstall Mode selected"
    sleep 1
    
    # Initialize selections for uninstall
    for i in "${!selections[@]}"; do
        if [[ "${selections[$i]}" == "installed" ]]; then
            selections[$i]="installed"
        else
            selections[$i]="available"
        fi
    done
    
    # Uninstall menu loop
    while true; do
        show_uninstall_menu
        read -p "Enter choice: " choice
        
        case $choice in
            d|D)
                break
                ;;
            m|M)
                echo "Switching to Install mode..."
                mode_choice="1"
                sleep 1
                break
                ;;
            A)
                # Select all installed packages for removal
                for i in "${!selections[@]}"; do
                    if [[ "${selections[$i]}" == "installed" ]]; then
                        selections[$i]="selected_for_uninstall"
                    fi
                done
                echo "✅ All installed packages marked for removal"
                sleep 1
                ;;
            c|C)
                # Clear selections
                for i in "${!selections[@]}"; do
                    if [[ "${selections[$i]}" == "selected_for_uninstall" ]]; then
                        selections[$i]="installed"
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
                        if [[ "${selections[$index]}" == "installed" ]]; then
                            selections[$index]="selected_for_uninstall"
                            echo "🔴 Marked for removal: ${all_packages[$index]}"
                        elif [[ "${selections[$index]}" == "selected_for_uninstall" ]]; then
                            selections[$index]="installed"
                            echo "✅ Unmark for removal: ${all_packages[$index]}"
                        elif [[ "${selections[$index]}" == "available" ]]; then
                            echo "ℹ️  ${all_packages[$index]} is not installed and cannot be uninstalled"
                        fi
                        sleep 1
                    else
                        echo "❌ Invalid number. Please enter 1-${#all_packages[@]}"
                        sleep 1
                    fi
                else
                    echo "❌ Invalid option. Please enter a number, A, c, d, or m"
                    sleep 1
                fi
                ;;
        esac
    done
    
    # If we switched to install mode, continue with install
    if [[ "$mode_choice" != "2" ]]; then
        # Reset selections for install mode
        for i in "${!selections[@]}"; do
            if is_installed "${all_packages[$i]}"; then
                selections[$i]="installed"
            else
                selections[$i]="available"
            fi
        done
    else
        # Collect packages to uninstall
        uninstall_packages=()
        for i in "${!selections[@]}"; do
            if [[ "${selections[$i]}" == "selected_for_uninstall" ]]; then
                uninstall_packages+=("${all_packages[$i]}")
            fi
        done
        
        if [ ${#uninstall_packages[@]} -eq 0 ]; then
            echo "❌ No packages selected for uninstallation. Exiting."
            exit 0
        fi
        
        echo
        echo "🗑️  Packages to uninstall:"
        printf ' - %s\n' "${uninstall_packages[@]}"
        echo
        
        read -p "Proceed with uninstallation? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Uninstallation cancelled."
            exit 0
        fi
        
        # Uninstall packages
        echo
        echo "⬇️ Uninstalling packages..."
        for pkg in "${uninstall_packages[@]}"; do
            echo "➡️ Removing $pkg..."
            if sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null || yay -Rns --noconfirm "$pkg"; then
                echo "✅ $pkg uninstalled successfully."
            else
                echo "❌ Failed to uninstall $pkg."
            fi
            echo
        done
        
        # Final summary
        echo
        echo "📊 Uninstallation Summary"
        echo "========================"
        echo "✅ Uninstalled packages:"
        printf ' - %s\n' "${uninstall_packages[@]}"
        
        echo
        echo "🎉 Package uninstallation complete!"
        exit 0
    fi
fi

# INSTALL MODE
if [[ "$mode_choice" == "1" ]]; then
    echo "📦 Install Mode selected"
    sleep 1
    
    # Install menu loop
    while true; do
        show_install_menu
        read -p "Enter choice: " choice
        
        case $choice in
            d|D)
                break
                ;;
            m|M)
                echo "Switching to Uninstall mode..."
                mode_choice="2"
                sleep 1
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
                    echo "❌ Invalid option. Please enter a number, a, u, c, d, or m"
                    sleep 1
                fi
                ;;
        esac
    done
    
    # If we switched to uninstall mode, restart the script logic
    if [[ "$mode_choice" != "1" ]]; then
        exec "$0"
    fi
fi

# Collect selected packages for installation (excluding already installed ones)
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

# Check for AUR packages (just for summary, no installation check needed)
aur_to_install=()
repo_to_install=()

for pkg in "${selected_packages[@]}"; do
    if [[ " ${aur_packages[@]} " =~ " ${pkg} " ]]; then
        aur_to_install+=("$pkg")
    else
        repo_to_install+=("$pkg")
    fi
done

# Update system
echo
echo "🔄 Starting system update..."
sudo pacman -Syyu --noconfirm

# Install all packages using yay (handles both repo and AUR)
if [ ${#selected_packages[@]} -gt 0 ]; then
    echo
    echo "⬇️ Installing packages using yay..."
    for pkg in "${selected_packages[@]}"; do
        echo "➡️ Installing $pkg..."
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

if [ ${#aur_to_install[@]} -gt 0 ]; then
    echo
    echo "📝 Note: The following packages were installed from AUR:"
    printf ' - %s\n' "${aur_to_install[@]}"
fi

echo
echo "🎉 Package installation complete!"