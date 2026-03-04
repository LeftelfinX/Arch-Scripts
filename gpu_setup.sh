#!/bin/bash

# Multi-GPU Driver Installation Script for Arch Linux
# Supports NVIDIA and AMD GPUs with ROCm and OpenCL tools

set -e

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration file to store user preferences
CONFIG_FILE="$HOME/.gpu-installer.conf"

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

print_info() {
    print_color "[INFO] $1" "$BLUE"
}

print_success() {
    print_color "[SUCCESS] $1" "$GREEN"
}

print_warning() {
    print_color "[WARNING] $1" "$YELLOW"
}

print_error() {
    print_color "[ERROR] $1" "$RED"
}

print_header() {
    echo ""
    print_color "═══════════════════════════════════════════════════════════════" "$PURPLE"
    print_color "                 $1" "$PURPLE"
    print_color "═══════════════════════════════════════════════════════════════" "$PURPLE"
    echo ""
}

print_menu_header() {
    echo ""
    print_color "┌─────────────────────────────────────────────────────────────┐" "$CYAN"
    printf "${CYAN}│${WHITE} %-60s ${CYAN}│${WHITE}\n" "$1"
    print_color "├─────────────────────────────────────────────────────────────┤" "$CYAN"
}

print_menu_item() {
    printf "${CYAN}│${WHITE} %2d) %-56s ${CYAN}│${WHITE}\n" "$1" "$2"
}

print_menu_footer() {
    print_color "└─────────────────────────────────────────────────────────────┘" "$CYAN"
}

print_checkbox() {
    if [[ $2 == true ]]; then
        printf "${CYAN}│${GREEN} [✓] %-57s ${CYAN}│${NC}\n" "$1"
    else
        printf "${CYAN}│${WHITE} [ ] %-57s ${CYAN}│${NC}\n" "$1"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Run as normal user (sudo will be used when needed)."
        exit 1
    fi
}

# Check if running on Arch Linux
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        print_error "This script is designed for Arch Linux only."
        exit 1
    fi
}

# Function to detect all GPUs
detect_gpus() {
    print_header "GPU DETECTION"
    
    NVIDIA_FOUND=false
    AMD_FOUND=false
    INTEL_FOUND=false
    
    # Check for NVIDIA GPUs
    if lspci | grep -i nvidia > /dev/null; then
        NVIDIA_FOUND=true
        NVIDIA_GPU=$(lspci | grep -i nvidia | grep -E "VGA|3D" | head -n1 | sed 's/.*: //')
        print_success "NVIDIA GPU detected: $NVIDIA_GPU"
        
        # Get NVIDIA GPU architecture
        if echo "$NVIDIA_GPU" | grep -qiE "RTX [0-9]+|GTX 16[0-9]+|GTX 10[0-9]+|TITAN (V|RTX)|Quadro (RTX|T[0-9]+)"; then
            NVIDIA_ARCH="modern"
        elif echo "$NVIDIA_GPU" | grep -qiE "GTX (6[0-9]{2}|7[0-9]{2}|9[0-9]{2})|Quadro (K[0-9]+|M[0-9]+)"; then
            NVIDIA_ARCH="kepler"
        elif echo "$NVIDIA_GPU" | grep -qiE "GT (4[0-9]{2}|5[0-9]{2})|Quadro [0-9]+"; then
            NVIDIA_ARCH="fermi"
        else
            NVIDIA_ARCH="unknown"
        fi
    fi
    
    # Check for AMD GPUs
    if lspci | grep -i amd > /dev/null || lspci | grep -i "advanced micro devices" > /dev/null; then
        AMD_FOUND=true
        AMD_GPU=$(lspci | grep -E "VGA|3D" | grep -i amd | head -n1 | sed 's/.*: //')
        print_success "AMD GPU detected: $AMD_GPU"
        
        # Determine AMD GPU family
        if echo "$AMD_GPU" | grep -qiE "(RX 5[0-9]{3}|RX 6[0-9]{3}|RX 7[0-9]{3}|Radeon VII|Vega|Navi)"; then
            AMD_FAMILY="gcn-rdna"  # GCN/RDNA architecture (RX 5000/6000/7000 series)
        elif echo "$AMD_GPU" | grep -qiE "(HD [0-9]{4}|R[0-9]{2}|R7|R9)"; then
            AMD_FAMILY="legacy-gcn" # Legacy GCN (HD 7000+)
        else
            AMD_FAMILY="unknown"
        fi
    fi
    
    # Check for Intel GPUs (for hybrid graphics)
    if lspci | grep -i intel | grep -E "VGA|3D|HD Graphics" > /dev/null; then
        INTEL_FOUND=true
        INTEL_GPU=$(lspci | grep -i intel | grep -E "VGA|3D|HD Graphics" | head -n1 | sed 's/.*: //')
        print_info "Intel GPU detected: $INTEL_GPU (integrated)"
    fi
    
    if [[ $NVIDIA_FOUND == false && $AMD_FOUND == false ]]; then
        print_error "No NVIDIA or AMD GPU detected. Exiting."
        exit 1
    fi
}

# Function to detect kernel
detect_kernel() {
    CURRENT_KERNEL=$(uname -r)
    if echo "$CURRENT_KERNEL" | grep -qi "lts"; then
        KERNEL_TYPE="lts"
    else
        KERNEL_TYPE="standard"
    fi
    print_info "Detected kernel: $CURRENT_KERNEL ($KERNEL_TYPE)"
}

# Function to suggest NVIDIA driver
suggest_nvidia_driver() {
    print_header "NVIDIA DRIVER SELECTION"
    
    case $NVIDIA_ARCH in
        modern)
            echo "Your NVIDIA GPU supports multiple driver options:"
            echo "1) Proprietary drivers (nvidia) - Most stable"
            echo "2) Open-source modules (nvidia-open) - Experimental, better for Wayland"
            
            if [[ $KERNEL_TYPE == "lts" ]]; then
                echo "3) LTS kernel drivers (nvidia-lts) - For LTS kernel"
                read -p "Choose driver [1-3] (default: 1): " nvidia_choice
                case $nvidia_choice in
                    2) NVIDIA_DRIVER="nvidia-open" ;;
                    3) NVIDIA_DRIVER="nvidia-lts" ;;
                    *) NVIDIA_DRIVER="nvidia" ;;
                esac
            else
                read -p "Choose driver [1-2] (default: 1): " nvidia_choice
                if [[ $nvidia_choice == "2" ]]; then
                    NVIDIA_DRIVER="nvidia-open"
                else
                    NVIDIA_DRIVER="nvidia"
                fi
            fi
            NVIDIA_DRIVER_BASE="$NVIDIA_DRIVER"
            ;;
        kepler)
            print_warning "Your NVIDIA GPU (Kepler series) requires legacy drivers (470xx)"
            NVIDIA_DRIVER="nvidia-470xx-dkms"
            NVIDIA_DRIVER_BASE="nvidia-470xx-dkms"
            NVIDIA_NEEDS_AUR=true
            ;;
        fermi)
            print_warning "Your NVIDIA GPU (Fermi series) requires legacy drivers (390xx)"
            NVIDIA_DRIVER="nvidia-390xx-dkms"
            NVIDIA_DRIVER_BASE="nvidia-390xx-dkms"
            NVIDIA_NEEDS_AUR=true
            ;;
        *)
            print_warning "Could not determine NVIDIA GPU series. Using standard driver."
            NVIDIA_DRIVER="nvidia"
            NVIDIA_DRIVER_BASE="nvidia"
            ;;
    esac
    
    print_info "Selected NVIDIA driver: $NVIDIA_DRIVER"
}

# Function to suggest AMD driver
suggest_amd_driver() {
    print_header "AMD DRIVER SELECTION"
    
    echo "AMD GPU driver options:"
    echo "1) AMDGPU (open-source) - Recommended for most modern AMD GPUs"
    echo "2) AMDGPU PRO (proprietary) - Professional/compute workloads"
    echo "3) Both (AMDGPU + PRO components for OpenCL/ROCm)"
    read -p "Choose driver [1-3] (default: 1): " amd_choice
    
    case $amd_choice in
        2)
            AMD_DRIVER="amdgpu-pro"
            AMD_DRIVER_BASE="amdgpu-pro-libgl"
            AMD_NEEDS_AUR=true
            ;;
        3)
            AMD_DRIVER="both"
            AMD_DRIVER_BASE="amdgpu"
            ;;
        *)
            AMD_DRIVER="amdgpu"
            AMD_DRIVER_BASE="amdgpu"
            ;;
    esac
    
    # Check ROCm compatibility
    if [[ $AMD_FAMILY == "gcn-rdna" ]]; then
        print_success "Your AMD GPU supports ROCm (GCN/RDNA architecture)"
        AMD_ROCM_SUPPORTED=true
    else
        print_warning "Your AMD GPU may have limited ROCm support"
        AMD_ROCM_SUPPORTED=false
    fi
}

# Function to display main menu
show_main_menu() {
    while true; do
        clear
        print_header "GPU DRIVER INSTALLATION MENU"
        
        echo -e "${WHITE}Detected GPUs:${NC}"
        [[ $NVIDIA_FOUND == true ]] && echo "  • NVIDIA: $NVIDIA_GPU"
        [[ $AMD_FOUND == true ]] && echo "  • AMD: $AMD_GPU"
        [[ $INTEL_FOUND == true ]] && echo "  • Intel: $INTEL_GPU"
        echo ""
        
        print_menu_header "SELECT COMPONENTS TO INSTALL"
        print_checkbox "NVIDIA Driver ($NVIDIA_DRIVER)" "$SELECT_NVIDIA"
        print_checkbox "AMD Driver ($AMD_DRIVER)" "$SELECT_AMD"
        print_checkbox "ROCm Stack (HIP, ROCclr, ROCblas)" "$SELECT_ROCM"
        print_checkbox "OpenCL for NVIDIA" "$SELECT_OPENCL_NVIDIA"
        print_checkbox "OpenCL for AMD" "$SELECT_OPENCL_AMD"
        print_checkbox "HIP (CUDA-to-AMD converter/runtime)" "$SELECT_HIP"
        print_checkbox "MIOpen (Deep Learning)" "$SELECT_MIOPEN"
        print_checkbox "NVIDIA Container Toolkit" "$SELECT_DCK_NVIDIA"
        print_checkbox "AMD Container Support (rocm-docker)" "$SELECT_DCK_AMD"
        print_checkbox "Vulkan drivers & tools" "$SELECT_VULKAN"
        print_checkbox "32-bit compatibility libraries" "$SELECT_32BIT"
        print_checkbox "VA-API video acceleration" "$SELECT_VAAPI"
        print_checkbox "Linux kernel headers" "$SELECT_HEADERS"
        print_menu_footer
        echo ""
        
        echo "Options:"
        echo "  [1-12] - Toggle component (toggle number)"
        echo "  [a] - Select all"
        echo "  [n] - Select none"
        echo "  [i] - Install selected components"
        echo "  [q] - Quit"
        echo ""
        read -p "Enter choice: " menu_choice
        
        case $menu_choice in
            1) SELECT_NVIDIA=$([[ $SELECT_NVIDIA == true ]] && echo false || echo true) ;;
            2) SELECT_AMD=$([[ $SELECT_AMD == true ]] && echo false || echo true) ;;
            3) SELECT_ROCM=$([[ $SELECT_ROCM == true ]] && echo false || echo true) ;;
            4) SELECT_OPENCL_NVIDIA=$([[ $SELECT_OPENCL_NVIDIA == true ]] && echo false || echo true) ;;
            5) SELECT_OPENCL_AMD=$([[ $SELECT_OPENCL_AMD == true ]] && echo false || echo true) ;;
            6) SELECT_HIP=$([[ $SELECT_HIP == true ]] && echo false || echo true) ;;
            7) SELECT_MIOPEN=$([[ $SELECT_MIOPEN == true ]] && echo false || echo true) ;;
            8) SELECT_DCK_NVIDIA=$([[ $SELECT_DCK_NVIDIA == true ]] && echo false || echo true) ;;
            9) SELECT_DCK_AMD=$([[ $SELECT_DCK_AMD == true ]] && echo false || echo true) ;;
            10) SELECT_VULKAN=$([[ $SELECT_VULKAN == true ]] && echo false || echo true) ;;
            11) SELECT_32BIT=$([[ $SELECT_32BIT == true ]] && echo false || echo true) ;;
            12) SELECT_VAAPI=$([[ $SELECT_VAAPI == true ]] && echo false || echo true) ;;
            13) SELECT_HEADERS=$([[ $SELECT_HEADERS == true ]] && echo false || echo true) ;;
            a|A)
                SELECT_NVIDIA=true
                SELECT_AMD=true
                SELECT_ROCM=true
                SELECT_OPENCL_NVIDIA=true
                SELECT_OPENCL_AMD=true
                SELECT_HIP=true
                SELECT_MIOPEN=true
                SELECT_DCK_NVIDIA=true
                SELECT_DCK_AMD=true
                SELECT_VULKAN=true
                SELECT_32BIT=true
                SELECT_VAAPI=true
                SELECT_HEADERS=true
                ;;
            n|N)
                SELECT_NVIDIA=false
                SELECT_AMD=false
                SELECT_ROCM=false
                SELECT_OPENCL_NVIDIA=false
                SELECT_OPENCL_AMD=false
                SELECT_HIP=false
                SELECT_MIOPEN=false
                SELECT_DCK_NVIDIA=false
                SELECT_DCK_AMD=false
                SELECT_VULKAN=false
                SELECT_32BIT=false
                SELECT_VAAPI=false
                SELECT_HEADERS=false
                ;;
            i|I) break ;;
            q|Q) exit 0 ;;
            *) print_warning "Invalid option" ; sleep 1 ;;
        esac
    done
}

# Function to confirm selections
confirm_selections() {
    clear
    print_header "CONFIRM SELECTIONS"
    
    echo -e "${WHITE}Components to install:${NC}"
    [[ $SELECT_NVIDIA == true ]] && echo "  • NVIDIA Driver ($NVIDIA_DRIVER)"
    [[ $SELECT_AMD == true ]] && echo "  • AMD Driver ($AMD_DRIVER)"
    [[ $SELECT_ROCM == true ]] && echo "  • ROCm Stack"
    [[ $SELECT_OPENCL_NVIDIA == true ]] && echo "  • OpenCL (NVIDIA)"
    [[ $SELECT_OPENCL_AMD == true ]] && echo "  • OpenCL (AMD)"
    [[ $SELECT_HIP == true ]] && echo "  • HIP"
    [[ $SELECT_MIOPEN == true ]] && echo "  • MIOpen"
    [[ $SELECT_DCK_NVIDIA == true ]] && echo "  • NVIDIA Container Toolkit"
    [[ $SELECT_DCK_AMD == true ]] && echo "  • AMD Container Support"
    [[ $SELECT_VULKAN == true ]] && echo "  • Vulkan"
    [[ $SELECT_32BIT == true ]] && echo "  • 32-bit libraries"
    [[ $SELECT_VAAPI == true ]] && echo "  • VA-API"
    [[ $SELECT_HEADERS == true ]] && echo "  • Kernel headers"
    echo ""
    
    read -p "Proceed with installation? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled."
        exit 0
    fi
}

# Function to check and enable multilib
enable_multilib() {
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        print_warning "Multilib repository is not enabled."
        read -p "Enable multilib now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
            sudo pacman -Sy
            print_success "Multilib repository enabled"
        fi
    fi
}

# Function to check and install AUR helper
check_aur_helper() {
    if [[ $NVIDIA_NEEDS_AUR == true ]] || [[ $AMD_NEEDS_AUR == true ]]; then
        if command -v yay &> /dev/null; then
            AUR_HELPER="yay"
        elif command -v paru &> /dev/null; then
            AUR_HELPER="paru"
        else
            print_warning "AUR helper needed. Installing yay..."
            sudo pacman -S --needed --noconfirm git base-devel
            git clone https://aur.archlinux.org/yay.git /tmp/yay
            (cd /tmp/yay && makepkg -si --noconfirm)
            AUR_HELPER="yay"
        fi
    fi
}

# Function to configure NVIDIA
configure_nvidia() {
    print_info "Configuring NVIDIA..."
    
    # Configure mkinitcpio
    sudo sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo sed -i 's/ kms / /g' /etc/mkinitcpio.conf
    
    # Configure bootloader
    if [[ -d /boot/grub ]] && [[ -f /etc/default/grub ]]; then
        if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi
    
    # Blacklist nouveau
    sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null << EOF
blacklist nouveau
options nouveau modeset=0
EOF
    
    print_success "NVIDIA configured"
}

# Function to configure AMD
configure_amd() {
    print_info "Configuring AMD..."
    
    # Add AMD modules to mkinitcpio
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 amdgpu)/' /etc/mkinitcpio.conf
    
    # Configure bootloader for AMD
    if [[ -d /boot/grub ]] && [[ -f /etc/default/grub ]]; then
        if [[ $AMD_FAMILY == "gcn-rdna" ]] && ! grep -q "amdgpu.si_support=1" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 radeon.si_support=0 amdgpu.si_support=1 radeon.cik_support=0 amdgpu.cik_support=1"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi
    
    print_success "AMD configured"
}

# Function to create pacman hooks
create_pacman_hooks() {
    print_info "Creating pacman hooks..."
    sudo mkdir -p /etc/pacman.d/hooks/
    
    if [[ $SELECT_NVIDIA == true ]]; then
        sudo tee /etc/pacman.d/hooks/nvidia.hook > /dev/null << EOF
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=$NVIDIA_DRIVER_BASE
Target=linux

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF
    fi
    
    print_success "Pacman hooks created"
}

# Function to install NVIDIA components
install_nvidia() {
    if [[ $SELECT_NVIDIA == false && $SELECT_OPENCL_NVIDIA == false && $SELECT_DCK_NVIDIA == false ]]; then
        return
    fi
    
    print_header "INSTALLING NVIDIA COMPONENTS"
    
    local NVIDIA_PACKAGES=()
    
    if [[ $SELECT_NVIDIA == true ]]; then
        if [[ $NVIDIA_NEEDS_AUR == true ]]; then
            $AUR_HELPER -S --noconfirm "$NVIDIA_DRIVER" nvidia-utils nvidia-settings
        else
            NVIDIA_PACKAGES+=("$NVIDIA_DRIVER" "nvidia-utils" "nvidia-settings")
        fi
    fi
    
    if [[ $SELECT_OPENCL_NVIDIA == true ]]; then
        NVIDIA_PACKAGES+=("ocl-icd" "opencl-nvidia")
        if [[ $SELECT_32BIT == true ]]; then
            NVIDIA_PACKAGES+=("lib32-opencl-nvidia")
        fi
    fi
    
    if [[ $SELECT_DCK_NVIDIA == true ]]; then
        NVIDIA_PACKAGES+=("nvidia-container-toolkit")
    fi
    
    if [[ ${#NVIDIA_PACKAGES[@]} -gt 0 ]]; then
        sudo pacman -S --noconfirm "${NVIDIA_PACKAGES[@]}"
    fi
    
    if [[ $SELECT_NVIDIA == true ]]; then
        configure_nvidia
    fi
}

# Function to install AMD components
install_amd() {
    if [[ $SELECT_AMD == false && $SELECT_OPENCL_AMD == false && $SELECT_DCK_AMD == false ]]; then
        return
    fi
    
    print_header "INSTALLING AMD COMPONENTS"
    
    local AMD_PACKAGES=()
    
    if [[ $SELECT_AMD == true ]]; then
        case $AMD_DRIVER in
            "amdgpu")
                AMD_PACKAGES+=("xf86-video-amdgpu" "mesa")
                if [[ $SELECT_32BIT == true ]]; then
                    AMD_PACKAGES+=("lib32-mesa")
                fi
                ;;
            "amdgpu-pro")
                $AUR_HELPER -S --noconfirm amdgpu-pro-libgl
                ;;
            "both")
                AMD_PACKAGES+=("xf86-video-amdgpu" "mesa")
                if [[ $SELECT_32BIT == true ]]; then
                    AMD_PACKAGES+=("lib32-mesa")
                fi
                $AUR_HELPER -S --noconfirm amdgpu-pro-libgl
                ;;
        esac
    fi
    
    if [[ $SELECT_OPENCL_AMD == true ]]; then
        if [[ $AMD_DRIVER == "amdgpu-pro" ]] || [[ $AMD_DRIVER == "both" ]]; then
            AMD_PACKAGES+=("opencl-amdgpu-pro" "roc-opencl")
        else
            $AUR_HELPER -S --noconfirm opencl-amd
        fi
    fi
    
    if [[ ${#AMD_PACKAGES[@]} -gt 0 ]]; then
        sudo pacman -S --noconfirm "${AMD_PACKAGES[@]}"
    fi
    
    if [[ $SELECT_AMD == true ]]; then
        configure_amd
    fi
}

# Function to install ROCm stack
install_rocm() {
    if [[ $SELECT_ROCM == false && $SELECT_HIP == false && $SELECT_MIOPEN == false ]]; then
        return
    fi
    
    print_header "INSTALLING ROCM STACK"
    
    local ROCM_PACKAGES=()
    
    # Add ROCm repository if not present
    if ! grep -q "rocm" /etc/pacman.conf; then
        echo -e "\n[rocm]\nServer = https://repo.radeon.com/rocm/archlinux" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
    fi
    
    if [[ $SELECT_ROCM == true ]]; then
        ROCM_PACKAGES+=("rocm-hip-sdk" "rocm-opencl-sdk" "rocminfo" "rocm-dev")
    fi
    
    if [[ $SELECT_HIP == true ]]; then
        ROCM_PACKAGES+=("hip" "hipblas" "hipsparse" "hipfft")
    fi
    
    if [[ $SELECT_MIOPEN == true ]]; then
        ROCM_PACKAGES+=("miopen-hip" "miopen-opencl")
    fi
    
    if [[ ${#ROCM_PACKAGES[@]} -gt 0 ]]; then
        sudo pacman -S --noconfirm "${ROCM_PACKAGES[@]}"
        
        # Add user to video and render groups for ROCm
        sudo usermod -a -G video,render $USER
        
        # Add ROCm to PATH
        echo 'export ROCM_PATH=/opt/rocm' >> ~/.bashrc
        echo 'export PATH=$ROCM_PATH/bin:$PATH' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=$ROCM_PATH/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
    fi
}

# Function to install common components
install_common() {
    print_header "INSTALLING COMMON COMPONENTS"
    
    local COMMON_PACKAGES=()
    
    if [[ $SELECT_VULKAN == true ]]; then
        COMMON_PACKAGES+=("vulkan-icd-loader" "vulkan-tools")
        if [[ $NVIDIA_FOUND == true ]]; then
            COMMON_PACKAGES+=("vulkan-nvidia")
        fi
        if [[ $AMD_FOUND == true ]]; then
            COMMON_PACKAGES+=("vulkan-radeon")
            if [[ $SELECT_32BIT == true ]]; then
                COMMON_PACKAGES+=("lib32-vulkan-radeon")
            fi
        fi
        if [[ $INTEL_FOUND == true ]]; then
            COMMON_PACKAGES+=("vulkan-intel")
            if [[ $SELECT_32BIT == true ]]; then
                COMMON_PACKAGES+=("lib32-vulkan-intel")
            fi
        fi
    fi
    
    if [[ $SELECT_VAAPI == true ]]; then
        if [[ $NVIDIA_FOUND == true ]]; then
            COMMON_PACKAGES+=("libva-vdpau-driver" "vdpauinfo")
        fi
        if [[ $AMD_FOUND == true ]]; then
            COMMON_PACKAGES+=("libva-mesa-driver" "mesa-vdpau")
            if [[ $SELECT_32BIT == true ]]; then
                COMMON_PACKAGES+=("lib32-libva-mesa-driver" "lib32-mesa-vdpau")
            fi
        fi
    fi
    
    if [[ $SELECT_HEADERS == true ]]; then
        COMMON_PACKAGES+=("linux-headers")
    fi
    
    if [[ ${#COMMON_PACKAGES[@]} -gt 0 ]]; then
        sudo pacman -S --noconfirm "${COMMON_PACKAGES[@]}"
    fi
}

# Function to regenerate initramfs
regenerate_initramfs() {
    print_info "Regenerating initramfs..."
    sudo mkinitcpio -P
    print_success "Initramfs regenerated"
}

# Function to verify installation
verify_installation() {
    print_header "VERIFYING INSTALLATION"
    
    if [[ $SELECT_NVIDIA == true ]] || [[ $SELECT_OPENCL_NVIDIA == true ]]; then
        if command -v nvidia-smi &> /dev/null; then
            print_info "NVIDIA SMI output:"
            nvidia-smi | head -n 10
        fi
    fi
    
    if [[ $SELECT_ROCM == true ]] || [[ $SELECT_AMD == true ]]; then
        if command -v rocminfo &> /dev/null; then
            print_info "ROCm devices:"
            rocminfo | grep "Name:" | head -n 5
        fi
    fi
    
    if [[ $SELECT_OPENCL_AMD == true ]] || [[ $SELECT_OPENCL_NVIDIA == true ]] || [[ $SELECT_ROCM == true ]]; then
        if command -v clinfo &> /dev/null; then
            print_info "OpenCL platforms:"
            clinfo | grep "Platform Name" | head -n 2
        fi
    fi
    
    if [[ $SELECT_VULKAN == true ]]; then
        if command -v vulkaninfo &> /dev/null; then
            print_info "Vulkan devices:"
            vulkaninfo --summary | grep "deviceName" | head -n 2
        fi
    fi
}

# Function to show installation summary
show_summary() {
    print_header "INSTALLATION COMPLETE"
    
    echo -e "${WHITE}Installed components:${NC}"
    [[ $SELECT_NVIDIA == true ]] && echo "  • NVIDIA Driver ($NVIDIA_DRIVER)"
    [[ $SELECT_AMD == true ]] && echo "  • AMD Driver ($AMD_DRIVER)"
    [[ $SELECT_ROCM == true ]] && echo "  • ROCm Stack"
    [[ $SELECT_OPENCL_NVIDIA == true ]] && echo "  • OpenCL (NVIDIA)"
    [[ $SELECT_OPENCL_AMD == true ]] && echo "  • OpenCL (AMD)"
    [[ $SELECT_HIP == true ]] && echo "  • HIP"
    [[ $SELECT_MIOPEN == true ]] && echo "  • MIOpen"
    [[ $SELECT_DCK_NVIDIA == true ]] && echo "  • NVIDIA Container Toolkit"
    [[ $SELECT_DCK_AMD == true ]] && echo "  • AMD Container Support"
    [[ $SELECT_VULKAN == true ]] && echo "  • Vulkan"
    [[ $SELECT_32BIT == true ]] && echo "  • 32-bit libraries"
    [[ $SELECT_VAAPI == true ]] && echo "  • VA-API"
    [[ $SELECT_HEADERS == true ]] && echo "  • Kernel headers"
    echo ""
    
    print_warning "You may need to log out and back in for group changes to take effect."
    print_warning "A system reboot is recommended to complete the setup."
}

# Main function
main() {
    clear
    print_header "MULTI-GPU DRIVER INSTALLER FOR ARCH LINUX"
    print_info "Supports NVIDIA and AMD GPUs with ROCm and OpenCL"
    
    # Initial checks
    check_root
    check_arch
    
    # Detect hardware
    detect_gpus
    detect_kernel
    
    # Initialize selection variables
    SELECT_NVIDIA=false
    SELECT_AMD=false
    SELECT_ROCM=false
    SELECT_OPENCL_NVIDIA=false
    SELECT_OPENCL_AMD=false
    SELECT_HIP=false
    SELECT_MIOPEN=false
    SELECT_DCK_NVIDIA=false
    SELECT_DCK_AMD=false
    SELECT_VULKAN=true
    SELECT_32BIT=false
    SELECT_VAAPI=false
    SELECT_HEADERS=true
    
    # Suggest drivers for detected GPUs
    if [[ $NVIDIA_FOUND == true ]]; then
        suggest_nvidia_driver
        SELECT_NVIDIA=true
    fi
    
    if [[ $AMD_FOUND == true ]]; then
        suggest_amd_driver
        SELECT_AMD=true
    fi
    
    # Check AUR helper if needed
    check_aur_helper
    
    # Show main menu
    show_main_menu
    
    # Confirm selections
    confirm_selections
    
    # Update system
    print_info "Updating system..."
    sudo pacman -Syu --noconfirm
    
    # Install components
    install_nvidia
    install_amd
    install_rocm
    install_common
    
    # Enable multilib if selected
    if [[ $SELECT_32BIT == true ]]; then
        enable_multilib
    fi
    
    # Create hooks and regenerate initramfs
    create_pacman_hooks
    regenerate_initramfs
    
    # Verify installation
    verify_installation
    
    # Show summary
    show_summary
    
    # Reboot prompt
    read -p "Reboot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        print_info "Please reboot your system when convenient."
    fi
}

# Run main function
main