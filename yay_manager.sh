#!/bin/bash

# yay installer/uninstaller for Arch Linux
# Usage: ./yay-manager.sh [install|uninstall|reinstall]

set -euo pipefail  # Strict mode

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script variables
SCRIPT_VERSION="1.0.0"
YAY_REPO="https://aur.archlinux.org/yay.git"
YAY_BIN="/usr/bin/yay"
YAY_CONFIG="$HOME/.config/yay"

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   yay Manager v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo "Options:"
    echo "  install     Install yay (default)"
    echo "  uninstall   Remove yay and its dependencies"
    echo "  reinstall   Reinstall yay"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install     # Install yay"
    echo "  $0 uninstall   # Uninstall yay"
    echo "  $0 reinstall   # Reinstall yay"
}

# Check if running as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then 
        print_error "Please do not run this script as root!"
        exit 1
    fi
}

# Check if running on Arch Linux
check_arch() {
    if [ ! -f /etc/arch-release ]; then
        print_error "This script is for Arch Linux only!"
        exit 1
    fi
}

# Check internet connection
check_internet() {
    print_status "Checking internet connection..."
    if ! ping -c 1 google.com &> /dev/null && ! ping -c 1 archlinux.org &> /dev/null; then
        print_error "No internet connection detected!"
        exit 1
    fi
}

# Check if yay is installed
is_yay_installed() {
    command -v yay &> /dev/null
}

# Find yay files and dependencies
find_yay_files() {
    print_status "Finding yay files..."
    
    # Find yay binary
    YAY_BIN_PATH=$(which yay 2>/dev/null || echo "")
    
    # Find yay related packages installed via makepkg
    YAY_PACKAGES=$(pacman -Qm 2>/dev/null | grep -i "yay" | cut -d' ' -f1 || echo "")
    
    # Find yay config directory
    if [ -d "$YAY_CONFIG" ]; then
        YAY_CONFIG_EXISTS=true
    else
        YAY_CONFIG_EXISTS=false
    fi
    
    # Find yay cache
    YAY_CACHE="$HOME/.cache/yay"
    if [ -d "$YAY_CACHE" ]; then
        YAY_CACHE_EXISTS=true
    else
        YAY_CACHE_EXISTS=false
    fi
}

# Uninstall yay
uninstall_yay() {
    print_header
    print_status "Starting yay uninstallation..."
    
    if ! is_yay_installed; then
        print_warning "yay is not installed!"
        read -p "Continue with cleanup anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    find_yay_files
    
    # Show what will be removed
    echo
    echo "The following will be removed:"
    if [ -n "$YAY_BIN_PATH" ]; then
        echo "  - Binary: $YAY_BIN_PATH"
    fi
    if [ -n "$YAY_PACKAGES" ]; then
        echo "  - Packages: $YAY_PACKAGES"
    fi
    if [ "$YAY_CONFIG_EXISTS" = true ]; then
        echo "  - Config directory: $YAY_CONFIG"
    fi
    if [ "$YAY_CACHE_EXISTS" = true ]; then
        echo "  - Cache directory: $YAY_CACHE"
    fi
    echo
    
    # Confirm uninstallation
    read -p "Are you sure you want to remove yay? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Uninstallation cancelled."
        exit 0
    fi
    
    # Remove packages
    if [ -n "$YAY_PACKAGES" ]; then
        print_status "Removing yay packages..."
        for pkg in $YAY_PACKAGES; do
            echo "Removing $pkg..."
            sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null || true
        done
    fi
    
    # Remove binary if still exists
    if [ -f "$YAY_BIN_PATH" ]; then
        print_status "Removing yay binary..."
        sudo rm -f "$YAY_BIN_PATH"
    fi
    
    # Remove config
    if [ "$YAY_CONFIG_EXISTS" = true ]; then
        print_status "Removing yay configuration..."
        rm -rf "$YAY_CONFIG"
    fi
    
    # Remove cache
    if [ "$YAY_CACHE_EXISTS" = true ]; then
        print_status "Removing yay cache..."
        rm -rf "$YAY_CACHE"
    fi
    
    # Clean any orphaned dependencies
    print_status "Cleaning orphaned dependencies..."
    ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
    if [ -n "$ORPHANS" ]; then
        echo "Removing orphaned packages..."
        sudo pacman -Rns --noconfirm $ORPHANS 2>/dev/null || true
    fi
    
    # Verify uninstallation
    if ! is_yay_installed; then
        echo
        echo "========================================"
        echo -e "${GREEN}✅ yay uninstalled successfully!${NC}"
        echo "========================================"
    else
        print_warning "Some yay components may still remain."
        echo "You may need to manually remove:"
        which yay 2>/dev/null && echo "  - $(which yay)"
    fi
}

# Install yay
install_yay() {
    print_header
    print_status "Starting yay installation..."
    
    # Check if already installed
    if is_yay_installed; then
        print_warning "yay is already installed!"
        echo "Current version: $(yay --version | head -n1)"
        echo
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
        uninstall_yay
    fi
    
    # Update system
    print_status "Updating system..."
    sudo pacman -Syu --noconfirm
    
    # Install dependencies
    print_status "Installing build dependencies..."
    sudo pacman -S --needed --noconfirm git base-devel
    
    # Create temp directory
    WORK_DIR=$(mktemp -d)
    cd "$WORK_DIR"
    
    # Clone repository
    print_status "Cloning yay repository..."
    if ! git clone "$YAY_REPO"; then
        print_error "Failed to clone repository!"
        cd / && rm -rf "$WORK_DIR"
        exit 1
    fi
    
    cd yay
    
    # Build and install
    print_status "Building yay (this may take a while)..."
    if ! makepkg -si --noconfirm; then
        print_error "Failed to build/install yay!"
        cd / && rm -rf "$WORK_DIR"
        exit 1
    fi
    
    # Clean up
    cd /
    rm -rf "$WORK_DIR"
    
    # Verify installation
    if is_yay_installed; then
        echo
        echo "========================================"
        echo -e "${GREEN}✅ yay installed successfully!${NC}"
        echo "========================================"
        echo "Version: $(yay --version | head -n1)"
        echo
        echo "Quick usage examples:"
        echo "  yay -S package        # Install package from AUR"
        echo "  yay -Syu              # Update system and AUR packages"
        echo "  yay -Ss keyword       # Search for packages"
        echo "  yay -Qi package       # Show package info"
        echo
    else
        print_error "Installation verification failed!"
        exit 1
    fi
}

# Reinstall yay
reinstall_yay() {
    print_status "Reinstalling yay..."
    if is_yay_installed; then
        uninstall_yay
    fi
    install_yay
}

# Main function
main() {
    # Check prerequisites
    check_not_root
    check_arch
    check_internet
    
    # Parse command line arguments
    ACTION="${1:-install}"
    
    case "$ACTION" in
        install)
            install_yay
            ;;
        uninstall)
            uninstall_yay
            ;;
        reinstall)
            reinstall_yay
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown option: $ACTION"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"