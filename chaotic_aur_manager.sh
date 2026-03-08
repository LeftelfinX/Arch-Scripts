#!/bin/bash

PACMAN_CONF="/etc/pacman.conf"
# Official key from Chaotic-AUR GitHub
CHAOTIC_KEY="3056513887B78AEB"
KEYSERVER="keyserver.ubuntu.com"

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variable to track if we have sudo
HAS_SUDO=false

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run commands with sudo
run_sudo() {
    if $HAS_SUDO; then
        sudo "$@"
    else
        "$@"
    fi
}

# Function to get sudo password
get_sudo_access() {
    if $HAS_SUDO; then
        return 0
    fi
    
    echo -e "${CYAN}This operation requires root privileges.${NC}"
    
    # Try to get sudo with password
    if sudo -v 2>/dev/null; then
        # If sudo is already cached or passwordless
        HAS_SUDO=true
        log_success "Root access granted"
        return 0
    fi
    
    # Ask for password
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        echo -n "[sudo] password for $USER: "
        read -s password
        echo ""
        
        # Test the password
        echo "$password" | sudo -S -v 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            # Password is correct, keep it for subsequent commands
            HAS_SUDO=true
            # Store password for the session
            SUDO_PASSWORD="$password"
            log_success "Root access granted"
            return 0
        else
            log_error "Sorry, try again."
            attempt=$((attempt + 1))
        fi
    done
    
    log_error "Maximum password attempts exceeded"
    return 1
}

# Function to run commands with sudo and password
run_sudo_with_pass() {
    if [[ -n "$SUDO_PASSWORD" ]]; then
        echo "$SUDO_PASSWORD" | sudo -S "$@"
    else
        sudo "$@"
    fi
}

# Check if running with sufficient privileges
check_privileges() {
    # Check if we're already root
    if [[ $EUID -eq 0 ]]; then
        HAS_SUDO=true
        return 0
    fi
    
    # Check if sudo is available
    if ! command -v sudo &>/dev/null; then
        log_error "sudo is not installed. Please install sudo or run as root."
        return 1
    fi
    
    return 0
}

# Check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 archlinux.org &>/dev/null; then
        log_error "No internet connection detected"
        return 1
    fi
    log_success "Internet connection available"
    return 0
}

# Check if repository is already installed
is_installed() {
    if grep -q "\[chaotic-aur\]" "$PACMAN_CONF" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Add the key using official method
add_chaotic_key() {
    log_info "Adding Chaotic-AUR key: $CHAOTIC_KEY"
    
    # Initialize pacman-key if needed
    if [[ ! -d /etc/pacman.d/gnupg ]]; then
        log_info "Initializing pacman keyring..."
        run_sudo_with_pass pacman-key --init
    fi
    
    # Receive the key from Ubuntu keyserver (as per official docs)
    log_info "Receiving key from $KEYSERVER..."
    if run_sudo_with_pass pacman-key --recv-key "$CHAOTIC_KEY" --keyserver "$KEYSERVER"; then
        log_success "Key received successfully"
    else
        log_error "Failed to receive key"
        return 1
    fi
    
    # Sign the key locally
    log_info "Signing key locally..."
    if run_sudo_with_pass pacman-key --lsign-key "$CHAOTIC_KEY"; then
        log_success "Key signed successfully"
        return 0
    else
        log_error "Failed to sign key"
        return 1
    fi
}

# Install the packages
install_chaotic_packages() {
    log_info "Installing Chaotic-AUR packages..."
    
    # Install keyring and mirrorlist packages
    if run_sudo_with_pass pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'; then
        log_success "Packages installed successfully"
        return 0
    else
        log_error "Failed to install packages"
        return 1
    fi
}

# Add repository to pacman.conf
add_to_pacman_conf() {
    if ! grep -q "\[chaotic-aur\]" "$PACMAN_CONF"; then
        log_info "Adding repository to $PACMAN_CONF"
        
        # Create backup
        run_sudo_with_pass cp "$PACMAN_CONF" "$PACMAN_CONF.backup"
        
        {
            echo ""
            echo "[chaotic-aur]"
            echo "Include = /etc/pacman.d/chaotic-mirrorlist"
        } | run_sudo_with_pass tee -a "$PACMAN_CONF" >/dev/null
        
        log_success "Repository added to pacman.conf"
    else
        log_info "Repository already in pacman.conf"
    fi
}

# Install the repository
install_repo() {
    echo ""
    log_info "Starting Chaotic-AUR installation..."
    echo "========================================="
    
    # Get sudo access
    if ! get_sudo_access; then
        log_error "Cannot proceed without root privileges"
        return 1
    fi
    
    # Check if already installed
    if is_installed; then
        log_warning "Chaotic-AUR appears to be already installed"
        read -p "Do you want to reinstall? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            return
        fi
        remove_repo
    fi
    
    # Step 1: Add the key
    log_info "Step 1: Adding Chaotic-AUR key..."
    if ! add_chaotic_key; then
        log_error "Failed at step 1: Key addition"
        return 1
    fi
    
    # Step 2: Install packages
    log_info "Step 2: Installing Chaotic-AUR packages..."
    if ! install_chaotic_packages; then
        log_error "Failed at step 2: Package installation"
        return 1
    fi
    
    # Step 3: Add to pacman.conf
    log_info "Step 3: Adding repository to configuration..."
    add_to_pacman_conf
    
    # Update package database
    log_info "Updating package database..."
    run_sudo_with_pass pacman -Syy
    
    echo "========================================="
    log_success "Chaotic-AUR installation completed!"
    echo "You can now install packages with: sudo pacman -S package-name"
}

# Remove the repository
remove_repo() {
    echo ""
    log_info "Removing Chaotic-AUR..."
    echo "========================================="
    
    # Get sudo access
    if ! get_sudo_access; then
        log_error "Cannot proceed without root privileges"
        return 1
    fi
    
    # Backup pacman.conf
    if [[ -f "$PACMAN_CONF" ]]; then
        run_sudo_with_pass cp "$PACMAN_CONF" "$PACMAN_CONF.backup.pre-remove"
        log_info "Created backup at $PACMAN_CONF.backup.pre-remove"
    fi
    
    # Remove packages
    log_info "Removing Chaotic-AUR packages..."
    if run_sudo_with_pass pacman -Rns --noconfirm chaotic-keyring chaotic-mirrorlist 2>/dev/null; then
        log_success "Packages removed"
    else
        log_info "Packages were not installed or already removed"
    fi
    
    # Remove from pacman.conf
    if grep -q "\[chaotic-aur\]" "$PACMAN_CONF" 2>/dev/null; then
        log_info "Removing repository from $PACMAN_CONF"
        run_sudo_with_pass sed -i '/\[chaotic-aur\]/,/Include = \/etc\/pacman.d\/chaotic-mirrorlist/d' "$PACMAN_CONF"
        log_success "Repository removed from pacman.conf"
    fi
    
    # Remove mirrorlist
    if [[ -f "/etc/pacman.d/chaotic-mirrorlist" ]]; then
        run_sudo_with_pass rm -f /etc/pacman.d/chaotic-mirrorlist
        log_info "Mirrorlist removed"
    fi
    
    # Remove the key from keyring
    log_info "Removing key from keyring..."
    run_sudo_with_pass pacman-key --delete "$CHAOTIC_KEY" 2>/dev/null
    
    # Update package database
    log_info "Updating package database..."
    run_sudo_with_pass pacman -Syy
    
    echo "========================================="
    log_success "Chaotic-AUR removal completed!"
}

# Reinstall the repository
reinstall_repo() {
    remove_repo
    install_repo
}

# Show status
show_status() {
    echo ""
    log_info "Checking Chaotic-AUR status..."
    echo "========================================="
    
    if is_installed; then
        log_success "Chaotic-AUR is installed"
        
        # Show key info
        if pacman -Q chaotic-keyring &>/dev/null; then
            echo "Keyring version: $(pacman -Q chaotic-keyring | cut -d' ' -f2)"
        fi
        
        if pacman -Q chaotic-mirrorlist &>/dev/null; then
            echo "Mirrorlist version: $(pacman -Q chaotic-mirrorlist | cut -d' ' -f2)"
        fi
        
        # Show enabled in pacman.conf
        if grep -q "\[chaotic-aur\]" "$PACMAN_CONF" 2>/dev/null; then
            echo "Repository enabled in pacman.conf"
        fi
        
        # Count available packages
        if pacman -Sl chaotic-aur &>/dev/null; then
            local pkg_count=$(pacman -Sl chaotic-aur 2>/dev/null | wc -l)
            echo "Available packages: $((pkg_count - 1))" # Subtract header line
        fi
        
        # Check if key is in keyring
        if run_sudo_with_pass pacman-key --list-keys "$CHAOTIC_KEY" &>/dev/null; then
            echo "Key is present in keyring"
        fi
    else
        log_info "Chaotic-AUR is not installed"
    fi
    echo "========================================="
}

# Clean up password on exit
cleanup() {
    unset SUDO_PASSWORD
    exit 0
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main menu
main() {
    # Check if we can get privileges when needed
    if ! check_privileges; then
        exit 1
    fi
    
    while true; do
        clear
        echo "========================================="
        echo "   Chaotic-AUR Manager (Arch Linux)"
        echo "========================================="
        echo "1. Install Chaotic-AUR"
        echo "2. Remove Chaotic-AUR"
        echo "3. Reinstall Chaotic-AUR"
        echo "4. Show Status"
        echo "5. Exit"
        echo "========================================="
        
        # Show current sudo status
        if $HAS_SUDO || [[ $EUID -eq 0 ]]; then
            echo -e "${GREEN}✓ Root access available${NC}"
        else
            echo -e "${YELLOW}⚠ Root access will be requested when needed${NC}"
        fi
        echo "========================================="
        
        read -p "Choose an option [1-5]: " choice
        
        case $choice in
            1)
                if check_internet; then
                    install_repo
                fi
                ;;
            2)
                if is_installed; then
                    read -p "Are you sure you want to remove Chaotic-AUR? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        remove_repo
                    else
                        log_info "Removal cancelled"
                    fi
                else
                    log_warning "Chaotic-AUR is not installed"
                fi
                ;;
            3)
                if check_internet; then
                    if is_installed; then
                        read -p "Are you sure you want to reinstall Chaotic-AUR? (y/N): " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            reinstall_repo
                        else
                            log_info "Reinstall cancelled"
                        fi
                    else
                        log_info "Chaotic-AUR not installed, proceeding with fresh install"
                        install_repo
                    fi
                fi
                ;;
            4)
                show_status
                ;;
            5)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please choose 1-5"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main