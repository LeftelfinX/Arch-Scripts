#!/bin/bash

echo "🔧 Base Packages Installer/Uninstaller"
echo "======================================="

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "🚫 This script should not be run as root. It will use sudo when needed."
    exit 1
fi

# Define categories and packages (all from official repos)
declare -A categories
categories=(
    ["System Information & Monitoring"]="fastfetch btop mission-center s-tui"
    ["GPU Tools"]="nvtop"
    ["Disk Utilities"]="filelight gnome-disk-utility"
    ["Network & Connectivity"]="networkmanager-openvpn"
    ["Compression Tools"]="unzip zip p7zip unrar xz tar gzip bzip2 lrzip lz4 zstd"
    ["File Management"]="tree"
    ["Documentation"]="tldr man"
    ["Graphics & Display"]="gwenview"
    ["Music and Video"]="amberol mpv"
    ["Power Management"]="power-profiles-daemon"
    ["Fonts"]="noto-fonts-cjk ttf-firacode-nerd"
    ["Essential CLI Tools"]="jq fzf ripgrep fd bat exa duf ncdu"
    ["System Utilities"]="htop glances fastfetch"
    ["Shell Enhancements"]="zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions"
    ["Development Tools"]="git base-devel"
    ["Network Tools"]="curl wget nmap traceroute"
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
    
    # Disk Utilities
    ["filelight"]="Disk usage analyzer with interactive pie charts"
    ["gnome-disk-utility"]="GUI for disk management and S.M.A.R.T. monitoring"
    
    # Network
    ["networkmanager-openvpn"]="OpenVPN plugin for NetworkManager"
    
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
    
    # Essential CLI Tools
    ["jq"]="Command-line JSON processor"
    ["fzf"]="Command-line fuzzy finder"
    ["ripgrep"]="Line-oriented search tool"
    ["fd"]="Simple and fast alternative to find"
    ["bat"]="Cat clone with syntax highlighting"
    ["exa"]="Modern replacement for ls"
    ["duf"]="Disk usage/free utility"
    ["ncdu"]="NCurses disk usage analyzer"
    
    # System Utilities
    ["htop"]="Interactive process viewer"
    ["glances"]="Cross-platform system monitoring tool"
    ["fastfetch"]="Lightweight system information tool (faster alternative to neofetch)"
    
    # Shell Enhancements
    ["zsh"]="Z shell"
    ["zsh-completions"]="Additional completion definitions for Zsh"
    ["zsh-syntax-highlighting"]="Syntax highlighting for Zsh"
    ["zsh-autosuggestions"]="Fish-like autosuggestions for Zsh"
    
    # Development Tools
    ["git"]="Distributed version control system"
    ["base-devel"]="Essential development tools"
    
    # Network Tools
    ["curl"]="Command-line tool for transferring data"
    ["wget"]="Network downloader"
    ["nmap"]="Network exploration tool"
    ["traceroute"]="Trace the route to a host"
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
    echo "  [r] Reverse selections (select/deselect all available)"
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
                            echo "✅ Unmarked for removal: ${all_packages[$index]}"
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
        
        # Arrays to track uninstall results
        successfully_uninstalled=()
        failed_uninstalls=()
        
        # Uninstall packages
        echo
        echo "⬇️ Uninstalling packages..."
        for pkg in "${uninstall_packages[@]}"; do
            echo "➡️ Removing $pkg..."
            if sudo pacman -Rns --noconfirm "$pkg"; then
                echo "✅ $pkg uninstalled successfully."
                successfully_uninstalled+=("$pkg")
            else
                echo "❌ Failed to uninstall $pkg."
                failed_uninstalls+=("$pkg")
            fi
            echo
        done
        
        # Final uninstall summary
        echo
        echo "📊 Uninstallation Summary"
        echo "========================"
        
        if [ ${#successfully_uninstalled[@]} -gt 0 ]; then
            echo "✅ Successfully uninstalled:"
            printf ' - %s\n' "${successfully_uninstalled[@]}"
            echo
        fi
        
        if [ ${#failed_uninstalls[@]} -gt 0 ]; then
            echo "❌ Failed to uninstall:"
            printf ' - %s\n' "${failed_uninstalls[@]}"
            echo
        fi
        
        # Overall status
        if [ ${#failed_uninstalls[@]} -eq 0 ]; then
            echo "🎉 All packages uninstalled successfully!"
        else
            echo "⚠️  Uninstallation completed with ${#failed_uninstalls[@]} failure(s)."
            exit 1
        fi
        
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
                            echo "ℹ️  ${all_packages[$index]} is already installed and cannot be selected for install"
                        fi
                        sleep 1
                    else
                        echo "❌ Invalid number. Please enter 1-${#all_packages[@]}"
                        sleep 1
                    fi
                else
                    echo "❌ Invalid option. Please enter a number, a, u, c, r, d, or m"
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
for pkg in "${selected_packages[@]}"; do
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

# Final installation summary
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

# Optional post-install configurations
echo
echo "🔧 Additional Configuration Options"
echo "==================================="

# Set Zsh as default shell if installed
if is_installed "zsh"; then
    read -p "Do you want to set Zsh as your default shell? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if chsh -s $(which zsh); then
            echo "✅ Default shell changed to Zsh. You'll need to log out and back in for changes to take effect."
        else
            echo "❌ Failed to change default shell"
        fi
    fi
fi

echo
echo "✨ All operations completed!"