#!/bin/bash

# GPU detection and installation script
# Detects NVIDIA, AMD, and Intel GPUs and installs appropriate packages

# ============================================
# COLOR DEFINITIONS
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[1;30m'
NC='\033[0m' # No Color

# ============================================
# UTILITY FUNCTIONS
# ============================================

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${MAGENTA}=== $1 ===${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

run_sudo() {
    echo -e "${YELLOW}[SUDO]${NC} Running: sudo $*"
    if sudo "$@"; then
        return 0
    else
        print_error "Command failed: sudo $*"
        return 1
    fi
}

check_sudo() {
    if ! sudo -v >/dev/null 2>&1; then
        print_error "This script requires sudo access to install packages"
        print_status "Please ensure you have sudo privileges and try again"
        exit 1
    fi
    
    # Keep sudo alive in the background
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# ============================================
# KERNEL HEADERS FUNCTIONS
# ============================================

get_running_kernel() {
    uname -r
}

get_installed_kernels() {
    pacman -Q | grep -E "linux( |$)" | cut -d' ' -f1 | sort -u
}

check_kernel_headers() {
    local kernel="$1"
    local headers_package=""
    
    case $kernel in
        *-lts*)
            headers_package="linux-lts-headers"
            ;;
        *-zen*)
            headers_package="linux-zen-headers"
            ;;
        *-hardened*)
            headers_package="linux-hardened-headers"
            ;;
        *)
            # Default kernel
            headers_package="linux-headers"
            ;;
    esac
    
    if package_installed "$headers_package"; then
        return 0
    else
        return 1
    fi
}

install_kernel_headers() {
    local kernel="$1"
    local headers_package=""
    
    case $kernel in
        *-lts*)
            headers_package="linux-lts-headers"
            ;;
        *-zen*)
            headers_package="linux-zen-headers"
            ;;
        *-hardened*)
            headers_package="linux-hardened-headers"
            ;;
        *)
            # Default kernel
            headers_package="linux-headers"
            ;;
    esac
    
    print_status "Installing kernel headers for $kernel..."
    if run_sudo pacman -S --noconfirm "$headers_package"; then
        print_success "Kernel headers installed: $headers_package"
        return 0
    else
        print_error "Failed to install kernel headers: $headers_package"
        return 1
    fi
}

ensure_kernel_headers() {
    local running_kernel=$(get_running_kernel)
    local headers_installed=false
    
    print_section "Kernel Headers Check"
    print_status "Running kernel: $running_kernel"
    
    # Check if headers for running kernel are installed
    if check_kernel_headers "$running_kernel"; then
        print_success "Kernel headers for $running_kernel are already installed"
        headers_installed=true
    else
        print_warning "Kernel headers for $running_kernel are not installed"
        read -p "Install kernel headers now? [Y/n] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if install_kernel_headers "$running_kernel"; then
                headers_installed=true
            fi
        fi
    fi
    
    # Check for other installed kernels that might need headers
    local installed_kernels=$(get_installed_kernels)
    for kernel in $installed_kernels; do
        if [ "$kernel" != "$running_kernel" ] && ! check_kernel_headers "$kernel"; then
            print_warning "Headers for $kernel are missing (may affect initramfs generation)"
        fi
    done
    
    if [ "$headers_installed" = false ]; then
        print_warning "Continuing without kernel headers. DKMS modules may fail to build."
        print_status "You can install headers later with: sudo pacman -S linux-headers (or linux-lts-headers, etc.)"
    fi
    
    return 0
}

# ============================================
# DKMS FIX FUNCTION
# ============================================

fix_dkms_paths() {
    print_section "DKMS Configuration Check"
    
    # Check if DKMS configuration needs fixing
    local dkms_conf="/etc/dkms/framework.conf"
    if [ -f "$dkms_conf" ]; then
        # Check if there's a problematic source tree configuration
        if grep -q "source_tree.*=.*/" "$dkms_conf" 2>/dev/null; then
            print_warning "Found potential DKMS path issue in $dkms_conf"
            print_status "Creating backup: ${dkms_conf}.bak"
            run_sudo cp "$dkms_conf" "${dkms_conf}.bak"
            
            # Comment out any source_tree lines that might cause issues
            run_sudo sed -i 's/^source_tree/#source_tree/g' "$dkms_conf"
            print_success "Fixed DKMS configuration"
        fi
    fi
    
    # Ensure DKMS has proper kernel source symlinks
    local kernel=$(get_running_kernel)
    local build_link="/lib/modules/${kernel}/build"
    local source_link="/lib/modules/${kernel}/source"
    
    if [ -L "$build_link" ] && [ ! -e "$build_link" ]; then
        print_warning "Broken kernel build symlink detected"
        run_sudo rm -f "$build_link"
    fi
    
    if [ ! -e "$build_link" ]; then
        print_status "Recreating kernel build symlink..."
        if [ -d "/usr/src/linux-${kernel}" ]; then
            run_sudo ln -sf "/usr/src/linux-${kernel}" "$build_link"
        elif [ -d "/usr/lib/modules/${kernel}/build" ]; then
            # Already exists but broken? Let's check
            :
        else
            print_warning "Kernel source directory not found. DKMS may fail."
        fi
    fi
    
    # Clean up any partially built modules that might cause issues
    if [ -d "/var/lib/dkms/nvidia" ]; then
        print_status "Checking for partial NVIDIA DKMS builds..."
        local nvidia_versions=$(ls /var/lib/dkms/nvidia/ 2>/dev/null)
        for version in $nvidia_versions; do
            if [ -d "/var/lib/dkms/nvidia/${version}/${kernel}" ]; then
                local build_log="/var/lib/dkms/nvidia/${version}/build/make.log"
                if [ -f "$build_log" ] && grep -q "Missing .* kernel headers" "$build_log" 2>/dev/null; then
                    print_warning "Found failed NVIDIA DKMS build for kernel ${kernel}"
                    print_status "Cleaning up failed build..."
                    run_sudo dkms remove "nvidia/${version}" --kernel "${kernel}" --all 2>/dev/null
                fi
            fi
        done
    fi
}

# ============================================
# INSTALLATION CHECK FUNCTIONS
# ============================================

check_nvidia_installation() {
    local total=0
    local installed=0
    local packages=(
        "nvidia-open-dkms"
        "nvidia-utils"
        "nvidia-settings"
        "opencl-nvidia"
        "cuda"
        "cudnn"
        "libxnvctrl"
        "libnvidia-container"
        "nvidia-container-toolkit"
    )
    
    for pkg in "${packages[@]}"; do
        total=$((total + 1))
        if package_installed "$pkg"; then
            installed=$((installed + 1))
        fi
    done
    
    if [ $installed -eq 0 ]; then
        echo "none"
    elif [ $installed -eq $total ]; then
        echo "full"
    else
        echo "partial"
    fi
}

check_amd_dgpu_installation() {
    local total=0
    local installed=0
    local packages=(
        "rocm-hip-sdk"
        "rocm-opencl-sdk"
        "rocm-ml-sdk"
    )
    
    for pkg in "${packages[@]}"; do
        total=$((total + 1))
        if package_installed "$pkg"; then
            installed=$((installed + 1))
        fi
    done
    
    if [ $installed -eq 0 ]; then
        echo "none"
    elif [ $installed -eq $total ]; then
        echo "full"
    else
        echo "partial"
    fi
}

check_amd_igpu_installation() {
    local total=0
    local installed=0
    local packages=(
        "rocm-hip-sdk"
        "rocm-opencl-sdk"
        "libva-mesa-driver"
        "mesa"
        "mesa-vdpau"
        "vulkan-radeon"
        "lib32-mesa"
        "lib32-vulkan-radeon"
    )
    
    for pkg in "${packages[@]}"; do
        total=$((total + 1))
        if package_installed "$pkg"; then
            installed=$((installed + 1))
        fi
    done
    
    if [ $installed -eq 0 ]; then
        echo "none"
    elif [ $installed -eq $total ]; then
        echo "full"
    else
        echo "partial"
    fi
}

check_intel_dgpu_installation() {
    local total=0
    local installed=0
    local packages=(
        "intel-compute-runtime"
        "intel-graphics-compiler"
        "level-zero"
        "intel-media-driver"
        "libva-intel-driver"
        "vulkan-intel"
        "intel-gpu-tools"
    )
    
    for pkg in "${packages[@]}"; do
        total=$((total + 1))
        if package_installed "$pkg"; then
            installed=$((installed + 1))
        fi
    done
    
    if [ $installed -eq 0 ]; then
        echo "none"
    elif [ $installed -eq $total ]; then
        echo "full"
    else
        echo "partial"
    fi
}

check_intel_igpu_installation() {
    local total=0
    local installed=0
    local packages=(
        "intel-media-driver"
        "libva-intel-driver"
        "vulkan-intel"
        "intel-gpu-tools"
        "mesa"
        "lib32-mesa"
        "libva-utils"
    )
    
    for pkg in "${packages[@]}"; do
        total=$((total + 1))
        if package_installed "$pkg"; then
            installed=$((installed + 1))
        fi
    done
    
    if [ $installed -eq 0 ]; then
        echo "none"
    elif [ $installed -eq $total ]; then
        echo "full"
    else
        echo "partial"
    fi
}

check_nvtop_installation() {
    if package_installed "nvtop"; then
        echo "full"
    else
        echo "none"
    fi
}

# ============================================
# GPU DETECTION FUNCTIONS
# ============================================

# Function to extract clean GPU name
extract_gpu_name() {
    local line="$1"
    local vendor="$2"
    local name=""
    
    # Remove PCI address and basic cleanup
    name=$(echo "$line" | sed -E 's/^[0-9a-f:\.]+ //')
    
    case $vendor in
        nvidia)
            # Try to extract NVIDIA model name
            if echo "$name" | grep -q "GeForce"; then
                # Extract GeForce model
                name=$(echo "$name" | grep -o "GeForce[^,]*" | sed 's/GeForce //g' | sed 's/\[//g' | sed 's/\]//g')
                # Clean up common patterns
                name=$(echo "$name" | sed 's/RTX/RTX/g' | sed 's/GTX/GTX/g')
            elif echo "$name" | grep -q "Quadro"; then
                name=$(echo "$name" | grep -o "Quadro[^,]*" | sed 's/\[//g' | sed 's/\]//g')
            elif echo "$name" | grep -q "Tesla"; then
                name=$(echo "$name" | grep -o "Tesla[^,]*" | sed 's/\[//g' | sed 's/\]//g')
            else
                # Try to get model from brackets if available
                if echo "$name" | grep -q "\[.*\]"; then
                    name=$(echo "$name" | grep -o "\[[^]]*\]" | head -1 | sed 's/\[//g' | sed 's/\]//g')
                else
                    # Fallback to removing vendor name
                    name=$(echo "$name" | sed 's/NVIDIA Corporation //g' | sed 's/NVIDIA //g')
                fi
            fi
            ;;
        amd)
            # Try to extract AMD model name
            if echo "$name" | grep -q "Radeon"; then
                # Extract Radeon model
                name=$(echo "$name" | grep -o "Radeon[^,]*" | sed 's/Radeon //g' | sed 's/\[//g' | sed 's/\]//g')
                # Clean up RX/RX series
                name=$(echo "$name" | sed 's/RX/RX/g')
            elif echo "$name" | grep -q "Ryzen"; then
                name=$(echo "$name" | grep -o "Ryzen[^,]*" | sed 's/\[//g' | sed 's/\]//g')
            else
                # Try to get model from brackets if available
                if echo "$name" | grep -q "\[.*\]"; then
                    name=$(echo "$name" | grep -o "\[[^]]*\]" | head -1 | sed 's/\[//g' | sed 's/\]//g')
                else
                    # Remove common prefixes
                    name=$(echo "$name" | sed 's/Advanced Micro Devices, Inc. //g' | sed 's/AMD //g' | sed 's/\[AMD/ATI\] //g' | sed 's/ATI //g')
                fi
            fi
            ;;
        intel)
            # Extract Intel model
            if echo "$name" | grep -q "UHD"; then
                name=$(echo "$name" | grep -o "UHD[^,]*" | sed 's/\[//g' | sed 's/\]//g')
            elif echo "$name" | grep -q "Iris"; then
                name=$(echo "$name" | grep -o "Iris[^,]*" | sed 's/\[//g' | sed 's/\]//g')
            elif echo "$name" | grep -q "HD Graphics"; then
                name=$(echo "$name" | grep -o "HD Graphics[^,]*" | sed 's/\[//g' | sed 's/\]//g')
            else
                # Try to get from brackets
                if echo "$name" | grep -q "\[.*\]"; then
                    name=$(echo "$name" | grep -o "\[[^]]*\]" | head -1 | sed 's/\[//g' | sed 's/\]//g')
                else
                    name=$(echo "$name" | sed 's/Intel Corporation //g' | sed 's/Intel //g')
                fi
            fi
            ;;
        *)
            # For other vendors, just clean up a bit
            name=$(echo "$name" | sed 's/\[.*\]//g' | sed 's/(.*)//g')
            ;;
    esac
    
    # Final cleanup: remove extra spaces and any remaining brackets
    name=$(echo "$name" | sed -E 's/^\s+|\s+$//g' | sed -E 's/\[|\]//g' | sed -E 's/\(|\)//g')
    
    # If name is still empty or too generic, use a simpler approach
    if [ -z "$name" ] || [ "$name" = "VGA compatible controller" ] || [ "$name" = "Display controller" ]; then
        # Try to get the last meaningful part
        name=$(echo "$line" | awk -F':' '{print $3}' | sed 's/^ //' | cut -d'[' -f1 | cut -d'(' -f1 | sed -E 's/^\s+|\s+$//g')
    fi
    
    # If still empty, provide a generic name
    if [ -z "$name" ]; then
        name="Unknown GPU"
    fi
    
    echo "$name"
}

detect_gpus() {
    print_section "GPU Detection"
    print_status "Scanning for available GPUs..."
    
    # Initialize counters and arrays
    NVIDIA_DGPU=0
    AMD_DGPU=0
    AMD_IGPU=0
    INTEL_DGPU=0
    INTEL_IGPU=0
    OTHER_GPUS=0
    
    # Arrays to store GPU details with clean names
    declare -g -a NVIDIA_GPUS=()
    declare -g -a AMD_DGPU_LIST=()
    declare -g -a AMD_IGPU_LIST=()
    declare -g -a INTEL_DGPU_LIST=()
    declare -g -a INTEL_IGPU_LIST=()
    declare -g -a OTHER_GPUS_LIST=()
    
    # Arrays to store counts of each model
    declare -g -A NVIDIA_MODELS=()
    declare -g -A AMD_DGPU_MODELS=()
    declare -g -A AMD_IGPU_MODELS=()
    declare -g -A INTEL_DGPU_MODELS=()
    declare -g -A INTEL_IGPU_MODELS=()
    
    # Parse GPU information and extract names
    while IFS= read -r line; do
        if echo "$line" | grep -qi "nvidia"; then
            gpu_name=$(extract_gpu_name "$line" "nvidia")
            NVIDIA_DGPU=$((NVIDIA_DGPU + 1))
            NVIDIA_GPUS+=("$gpu_name")
            # Count models
            NVIDIA_MODELS["$gpu_name"]=$((NVIDIA_MODELS["$gpu_name"] + 1))
        elif echo "$line" | grep -qi "amd" || echo "$line" | grep -qi "ati"; then
            gpu_name=$(extract_gpu_name "$line" "amd")
            # Check if it's likely an iGPU (integrated) or dGPU (discrete)
            if echo "$line" | grep -qi "Renoir\|Raven\|Cezanne\|Rembrandt\|Phoenix\|Strix\|Van Gogh\|Graphics\|Ryzen\|Radeon Graphics"; then
                AMD_IGPU=$((AMD_IGPU + 1))
                AMD_IGPU_LIST+=("$gpu_name")
                AMD_IGPU_MODELS["$gpu_name"]=$((AMD_IGPU_MODELS["$gpu_name"] + 1))
            else
                AMD_DGPU=$((AMD_DGPU + 1))
                AMD_DGPU_LIST+=("$gpu_name")
                AMD_DGPU_MODELS["$gpu_name"]=$((AMD_DGPU_MODELS["$gpu_name"] + 1))
            fi
        elif echo "$line" | grep -qi "intel"; then
            gpu_name=$(extract_gpu_name "$line" "intel")
            # Check if it's likely an iGPU (integrated) or dGPU (discrete)
            if echo "$line" | grep -qi "HD Graphics\|UHD Graphics\|Iris Xe\|Graphics\|Gen[0-9]\|Integrated"; then
                INTEL_IGPU=$((INTEL_IGPU + 1))
                INTEL_IGPU_LIST+=("$gpu_name")
                INTEL_IGPU_MODELS["$gpu_name"]=$((INTEL_IGPU_MODELS["$gpu_name"] + 1))
            else
                INTEL_DGPU=$((INTEL_DGPU + 1))
                INTEL_DGPU_LIST+=("$gpu_name")
                INTEL_DGPU_MODELS["$gpu_name"]=$((INTEL_DGPU_MODELS["$gpu_name"] + 1))
            fi
        else
            gpu_name=$(extract_gpu_name "$line" "other")
            OTHER_GPUS=$((OTHER_GPUS + 1))
            OTHER_GPUS_LIST+=("$gpu_name")
        fi
    done < <(lspci | grep -E "VGA|3D|Display")
}

display_gpus() {
    echo -e "\n${WHITE}Detected GPUs:${NC}"
    
    # Display NVIDIA GPUs with model counts
    if [ ${#NVIDIA_GPUS[@]} -gt 0 ]; then
        for model in "${!NVIDIA_MODELS[@]}"; do
            count=${NVIDIA_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${GREEN}• NVIDIA dGPU:${NC} $model ${GREEN}(x$count)${NC}"
            else
                echo -e "  ${GREEN}• NVIDIA dGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• NVIDIA dGPU: None detected${NC}"
    fi
    
    # Display AMD dGPUs with model counts
    if [ ${#AMD_DGPU_LIST[@]} -gt 0 ]; then
        for model in "${!AMD_DGPU_MODELS[@]}"; do
            count=${AMD_DGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${RED}• AMD dGPU:${NC} $model ${RED}(x$count)${NC}"
            else
                echo -e "  ${RED}• AMD dGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• AMD dGPU: None detected${NC}"
    fi
    
    # Display AMD iGPUs with model counts
    if [ ${#AMD_IGPU_LIST[@]} -gt 0 ]; then
        for model in "${!AMD_IGPU_MODELS[@]}"; do
            count=${AMD_IGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${RED}• AMD iGPU:${NC} $model ${RED}(x$count)${NC}"
            else
                echo -e "  ${RED}• AMD iGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• AMD iGPU: None detected${NC}"
    fi
    
    # Display Intel dGPUs with model counts
    if [ ${#INTEL_DGPU_LIST[@]} -gt 0 ]; then
        for model in "${!INTEL_DGPU_MODELS[@]}"; do
            count=${INTEL_DGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${CYAN}• Intel dGPU:${NC} $model ${CYAN}(x$count)${NC}"
            else
                echo -e "  ${CYAN}• Intel dGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• Intel dGPU: None detected${NC}"
    fi
    
    # Display Intel iGPUs with model counts
    if [ ${#INTEL_IGPU_LIST[@]} -gt 0 ]; then
        for model in "${!INTEL_IGPU_MODELS[@]}"; do
            count=${INTEL_IGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${CYAN}• Intel iGPU:${NC} $model ${CYAN}(x$count)${NC}"
            else
                echo -e "  ${CYAN}• Intel iGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• Intel iGPU: None detected${NC}"
    fi
    
    # Display Other GPUs
    if [ ${#OTHER_GPUS_LIST[@]} -gt 0 ]; then
        for gpu in "${OTHER_GPUS_LIST[@]}"; do
            echo -e "  ${YELLOW}• Other GPU:${NC} $gpu"
        done
    fi
    
    # Summary with counts
    echo -e "\n${WHITE}Detection Summary:${NC}"
    [ "$NVIDIA_DGPU" -gt 0 ] && echo -e "  ${GREEN}• NVIDIA dGPUs: $NVIDIA_DGPU${NC}" || echo -e "  ${GRAY}• NVIDIA dGPUs: 0 (not detected)${NC}"
    [ "$AMD_DGPU" -gt 0 ] && echo -e "  ${RED}• AMD dGPUs: $AMD_DGPU${NC}" || echo -e "  ${GRAY}• AMD dGPUs: 0 (not detected)${NC}"
    [ "$AMD_IGPU" -gt 0 ] && echo -e "  ${RED}• AMD iGPUs: $AMD_IGPU${NC}" || echo -e "  ${GRAY}• AMD iGPUs: 0 (not detected)${NC}"
    [ "$INTEL_DGPU" -gt 0 ] && echo -e "  ${CYAN}• Intel dGPUs: $INTEL_DGPU${NC}" || echo -e "  ${GRAY}• Intel dGPUs: 0 (not detected)${NC}"
    [ "$INTEL_IGPU" -gt 0 ] && echo -e "  ${CYAN}• Intel iGPUs: $INTEL_IGPU${NC}" || echo -e "  ${GRAY}• Intel iGPUs: 0 (not detected)${NC}"
    [ "$OTHER_GPUS" -gt 0 ] && echo -e "  ${YELLOW}• Other GPUs: $OTHER_GPUS${NC}"
}

# ============================================
# GPU SETUP FUNCTIONS
# ============================================

setup_nvidia_dgpu() {
    print_section "Setting up NVIDIA dGPU"
    
    # First ensure kernel headers are installed
    ensure_kernel_headers
    
    # Fix any DKMS path issues
    fix_dkms_paths
    
    local packages=(
        "nvidia-open-dkms"
        "nvidia-utils"
        "nvidia-settings"
        "opencl-nvidia"
        "cuda"
        "cudnn"
        "libxnvctrl"
        "libnvidia-container"
        "nvidia-container-toolkit"
    )
    
    print_status "Installing NVIDIA dGPU packages..."
    if run_sudo pacman -S --noconfirm "${packages[@]}"; then
        print_success "NVIDIA dGPU packages installed successfully"
    else
        print_error "Failed to install some NVIDIA dGPU packages"
        return 1
    fi
    
    # Configure NVIDIA modules
    local modules_conf="/etc/modules-load.d/nvidia.conf"
    if [ ! -f "$modules_conf" ]; then
        print_status "Configuring NVIDIA modules..."
        {
            echo "nvidia"
            echo "nvidia_modeset"
            echo "nvidia_uvm"
            echo "nvidia_drm"
        } | run_sudo tee "$modules_conf" >/dev/null
        print_success "NVIDIA modules configured"
    fi
    
    # Blacklist nouveau if not already blacklisted
    local nouveau_conf="/etc/modprobe.d/blacklist-nouveau.conf"
    if [ ! -f "$nouveau_conf" ]; then
        print_status "Blacklisting nouveau driver..."
        echo "blacklist nouveau" | run_sudo tee "$nouveau_conf" >/dev/null
        print_success "Nouveau driver blacklisted"
    fi
    
    # Regenerate initramfs to include NVIDIA modules
    print_status "Regenerating initramfs..."
    run_sudo mkinitcpio -P
    
    return 0
}

setup_amd_dgpu() {
    print_section "Setting up AMD dGPU"
    
    local packages=(
        "rocm-hip-sdk"
        "rocm-opencl-sdk"
        "rocm-ml-sdk"
    )
    
    print_status "Installing AMD dGPU packages..."
    if run_sudo pacman -S --noconfirm "${packages[@]}"; then
        print_success "AMD dGPU packages installed successfully"
    else
        print_error "Failed to install some AMD dGPU packages"
        return 1
    fi
    
    # Configure ROCm permissions
    local rocm_rules="/etc/udev/rules.d/70-rocm.rules"
    if [ ! -f "$rocm_rules" ]; then
        print_status "Configuring ROCm udev rules..."
        {
            echo 'SUBSYSTEM=="kfd", KERNEL=="kfd", GROUP="video", MODE="0660"'
            echo 'SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0660"'
        } | run_sudo tee "$rocm_rules" >/dev/null
        print_success "ROCm udev rules configured"
    fi
    
    # Add user to groups
    run_sudo usermod -a -G video,render "$USER"
    print_success "Added user to video and render groups"
    
    return 0
}

setup_amd_igpu() {
    print_section "Setting up AMD iGPU"
    
    local packages=(
        "rocm-hip-sdk"           # ROCm for compute
        "rocm-opencl-sdk"        # OpenCL support
        "libva-mesa-driver"      # VA-API for video acceleration
        "mesa"                    # Mesa for OpenGL
        "mesa-vdpau"              # VDPAU for video
        "vulkan-radeon"           # Vulkan driver
        "lib32-mesa"              # 32-bit Mesa
        "lib32-vulkan-radeon"     # 32-bit Vulkan
    )
    
    print_status "Installing AMD iGPU packages..."
    if run_sudo pacman -S --noconfirm "${packages[@]}"; then
        print_success "AMD iGPU packages installed successfully"
    else
        print_error "Failed to install some AMD iGPU packages"
        return 1
    fi
    
    # Configure AMDGPU module parameters
    local amdgpu_conf="/etc/modprobe.d/amdgpu.conf"
    if [ ! -f "$amdgpu_conf" ]; then
        print_status "Configuring AMDGPU module parameters..."
        echo "options amdgpu si_support=1 cik_support=1" | run_sudo tee "$amdgpu_conf" >/dev/null
        print_success "AMDGPU module configured"
    fi
    
    # Add user to groups
    run_sudo usermod -a -G video,render "$USER"
    print_success "Added user to video and render groups"
    
    # Configure environment variables for ROCm on iGPU
    local environment_conf="/etc/environment"
    if ! grep -q "HSA_OVERRIDE_GFX_VERSION" "$environment_conf" 2>/dev/null; then
        print_status "Configuring ROCm environment for iGPU..."
        echo "HSA_OVERRIDE_GFX_VERSION=10.3.0" | run_sudo tee -a "$environment_conf" >/dev/null
        print_success "ROCm environment configured for iGPU"
    fi
    
    return 0
}

setup_intel_dgpu() {
    print_section "Setting up Intel dGPU"
    
    local packages=(
        "intel-compute-runtime"      # OpenCL/Level Zero support
        "intel-graphics-compiler"    # Intel Graphics Compiler
        "level-zero"                 # Level Zero API
        "intel-media-driver"         # Media driver
        "libva-intel-driver"         # VA-API driver
        "vulkan-intel"               # Vulkan driver
        "intel-gpu-tools"            # Intel GPU tools
    )
    
    print_status "Installing Intel dGPU packages..."
    if run_sudo pacman -S --noconfirm "${packages[@]}"; then
        print_success "Intel dGPU packages installed successfully"
    else
        print_error "Failed to install some Intel dGPU packages"
        return 1
    fi
    
    # Add user to groups
    run_sudo usermod -a -G video,render "$USER"
    print_success "Added user to video and render groups"
    
    # Configure VA-API
    local vaapi_conf="/etc/environment"
    if ! grep -q "LIBVA_DRIVER_NAME" "$vaapi_conf" 2>/dev/null; then
        print_status "Configuring VA-API..."
        echo "LIBVA_DRIVER_NAME=iHD" | run_sudo tee -a "$vaapi_conf" >/dev/null
        print_success "VA-API configured"
    fi
    
    return 0
}

setup_intel_igpu() {
    print_section "Setting up Intel iGPU"
    
    local packages=(
        "intel-media-driver"      # Media driver for hardware acceleration
        "libva-intel-driver"      # Legacy VA-API driver
        "vulkan-intel"            # Intel Vulkan driver
        "intel-gpu-tools"         # Intel GPU tools
        "mesa"                    # Mesa for OpenGL
        "lib32-mesa"              # 32-bit Mesa
        "libva-utils"             # VA-API utilities
    )
    
    print_status "Installing Intel iGPU packages..."
    if run_sudo pacman -S --noconfirm "${packages[@]}"; then
        print_success "Intel iGPU packages installed successfully"
    else
        print_error "Failed to install some Intel iGPU packages"
        return 1
    fi
    
    # Add user to groups
    run_sudo usermod -a -G video,render "$USER"
    print_success "Added user to video and render groups"
    
    # Configure i915 module parameters for better performance
    local i915_conf="/etc/modprobe.d/i915.conf"
    if [ ! -f "$i915_conf" ]; then
        print_status "Configuring i915 module parameters..."
        echo "options i915 enable_guc=2 enable_fbc=1 enable_psr=0" | run_sudo tee "$i915_conf" >/dev/null
        print_success "i915 module parameters configured"
    fi
    
    # Configure VA-API
    local vaapi_conf="/etc/environment"
    if ! grep -q "LIBVA_DRIVER_NAME" "$vaapi_conf" 2>/dev/null; then
        print_status "Configuring VA-API..."
        echo "LIBVA_DRIVER_NAME=iHD" | run_sudo tee -a "$vaapi_conf" >/dev/null
        print_success "VA-API configured"
    fi
    
    return 0
}

# ============================================
# UNIVERSAL TOOLS SETUP
# ============================================

setup_nvtop() {
    if ! command_exists nvtop; then
        print_status "Installing nvtop (universal GPU monitor)..."
        run_sudo pacman -S --noconfirm nvtop
        print_success "nvtop installed"
    else
        print_success "nvtop already installed"
    fi
}

# ============================================
# INTERACTIVE MENU FUNCTIONS
# ============================================

show_menu() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║     GPU Installation Selection Menu        ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${WHITE}Detected GPUs:${NC}"
    
    # Show detected GPUs with clean names and counts
    if [ ${#NVIDIA_GPUS[@]} -gt 0 ]; then
        for model in "${!NVIDIA_MODELS[@]}"; do
            count=${NVIDIA_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${GREEN}• NVIDIA dGPU:${NC} $model ${GREEN}(x$count)${NC}"
            else
                echo -e "  ${GREEN}• NVIDIA dGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• NVIDIA dGPU: None detected${NC}"
    fi
    
    if [ ${#AMD_DGPU_LIST[@]} -gt 0 ]; then
        for model in "${!AMD_DGPU_MODELS[@]}"; do
            count=${AMD_DGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${RED}• AMD dGPU:${NC} $model ${RED}(x$count)${NC}"
            else
                echo -e "  ${RED}• AMD dGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• AMD dGPU: None detected${NC}"
    fi
    
    if [ ${#AMD_IGPU_LIST[@]} -gt 0 ]; then
        for model in "${!AMD_IGPU_MODELS[@]}"; do
            count=${AMD_IGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${RED}• AMD iGPU:${NC} $model ${RED}(x$count)${NC}"
            else
                echo -e "  ${RED}• AMD iGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• AMD iGPU: None detected${NC}"
    fi
    
    if [ ${#INTEL_DGPU_LIST[@]} -gt 0 ]; then
        for model in "${!INTEL_DGPU_MODELS[@]}"; do
            count=${INTEL_DGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${CYAN}• Intel dGPU:${NC} $model ${CYAN}(x$count)${NC}"
            else
                echo -e "  ${CYAN}• Intel dGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• Intel dGPU: None detected${NC}"
    fi
    
    if [ ${#INTEL_IGPU_LIST[@]} -gt 0 ]; then
        for model in "${!INTEL_IGPU_MODELS[@]}"; do
            count=${INTEL_IGPU_MODELS["$model"]}
            if [ "$count" -gt 1 ]; then
                echo -e "  ${CYAN}• Intel iGPU:${NC} $model ${CYAN}(x$count)${NC}"
            else
                echo -e "  ${CYAN}• Intel iGPU:${NC} $model"
            fi
        done
    else
        echo -e "  ${GRAY}• Intel iGPU: None detected${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}Select components to install (use numbers to toggle):${NC}"
    echo ""
    
    # Check installation status for each component
    NVIDIA_STATUS=$(check_nvidia_installation)
    AMD_DGPU_STATUS=$(check_amd_dgpu_installation)
    AMD_IGPU_STATUS=$(check_amd_igpu_installation)
    INTEL_DGPU_STATUS=$(check_intel_dgpu_installation)
    INTEL_IGPU_STATUS=$(check_intel_igpu_installation)
    NVTOP_STATUS=$(check_nvtop_installation)
    
    # Function to get status symbol
    get_status_symbol() {
        local status=$1
        case $status in
            "full") echo "${GREEN}✓${NC}" ;;
            "partial") echo "${YELLOW}~${NC}" ;;
            *) echo "${RED}✗${NC}" ;;
        esac
    }
    
    # NVIDIA dGPU (always shown)
    if [ "$NVIDIA_DGPU" -gt 0 ]; then
        local status_symbol=$(get_status_symbol "$NVIDIA_STATUS")
        echo -e "  ${GREEN}1.${NC} NVIDIA dGPU [${status_symbol}${GREEN}]${NC}"
    else
        echo -e "  ${GRAY}1. NVIDIA dGPU [UNAVAILABLE]${NC}"
    fi
    
    # AMD dGPU (always shown)
    if [ "$AMD_DGPU" -gt 0 ]; then
        local status_symbol=$(get_status_symbol "$AMD_DGPU_STATUS")
        echo -e "  ${RED}2.${NC} AMD dGPU [${status_symbol}${RED}]${NC}"
    else
        echo -e "  ${GRAY}2. AMD dGPU [UNAVAILABLE]${NC}"
    fi
    
    # AMD iGPU (always shown)
    if [ "$AMD_IGPU" -gt 0 ]; then
        local status_symbol=$(get_status_symbol "$AMD_IGPU_STATUS")
        echo -e "  ${RED}3.${NC} AMD iGPU [${status_symbol}${RED}]${NC}"
    else
        echo -e "  ${GRAY}3. AMD iGPU [UNAVAILABLE]${NC}"
    fi
    
    # Intel dGPU (always shown)
    if [ "$INTEL_DGPU" -gt 0 ]; then
        local status_symbol=$(get_status_symbol "$INTEL_DGPU_STATUS")
        echo -e "  ${CYAN}4.${NC} Intel dGPU [${status_symbol}${CYAN}]${NC}"
    else
        echo -e "  ${GRAY}4. Intel dGPU [UNAVAILABLE]${NC}"
    fi
    
    # Intel iGPU (always shown)
    if [ "$INTEL_IGPU" -gt 0 ]; then
        local status_symbol=$(get_status_symbol "$INTEL_IGPU_STATUS")
        echo -e "  ${CYAN}5.${NC} Intel iGPU [${status_symbol}${CYAN}]${NC}"
    else
        echo -e "  ${GRAY}5. Intel iGPU [UNAVAILABLE]${NC}"
    fi
    
    # nvtop (always available)
    local nvtop_status_symbol=$(get_status_symbol "$NVTOP_STATUS")
    echo -e "  ${BLUE}6.${NC} nvtop (GPU monitor) [${nvtop_status_symbol}${BLUE}]${NC}"
    
    echo ""
    echo -e "  ${MAGENTA}a.${NC} Select All (available components only)"
    echo -e "  ${MAGENTA}n.${NC} Select None"
    echo -e "  ${GREEN}c.${NC} Continue with selected"
    echo -e "  ${RED}q.${NC} Quit"
    echo ""
    echo -e "${WHITE}Current selection:${NC} $(get_selection_summary)"
    echo -e "${WHITE}Legend:${NC} ${GREEN}✓${NC}=Full ${YELLOW}~${NC}=Partial ${RED}✗${NC}=None"
    echo ""
}

get_selection_summary() {
    local selected=()
    
    # Check each available GPU and nvtop
    [ "$NVIDIA_DGPU" -gt 0 ] && [ "${SELECTIONS[0]}" = true ] && selected+=("NVIDIA")
    [ "$AMD_DGPU" -gt 0 ] && [ "${SELECTIONS[1]}" = true ] && selected+=("AMD dGPU")
    [ "$AMD_IGPU" -gt 0 ] && [ "${SELECTIONS[2]}" = true ] && selected+=("AMD iGPU")
    [ "$INTEL_DGPU" -gt 0 ] && [ "${SELECTIONS[3]}" = true ] && selected+=("Intel dGPU")
    [ "$INTEL_IGPU" -gt 0 ] && [ "${SELECTIONS[4]}" = true ] && selected+=("Intel iGPU")
    [ "${SELECTIONS[5]}" = true ] && selected+=("nvtop")
    
    if [ ${#selected[@]} -eq 0 ]; then
        echo -e "${RED}None${NC}"
    else
        echo -e "${GREEN}${selected[*]}${NC}"
    fi
}

toggle_selection() {
    local option=$1
    # Only allow toggling if the option is within range
    if [ "$option" -ge 0 ] && [ "$option" -lt ${#SELECTIONS[@]} ]; then
        # Check if the option corresponds to an available GPU
        local can_toggle=false
        case $option in
            0) [ "$NVIDIA_DGPU" -gt 0 ] && can_toggle=true ;;
            1) [ "$AMD_DGPU" -gt 0 ] && can_toggle=true ;;
            2) [ "$AMD_IGPU" -gt 0 ] && can_toggle=true ;;
            3) [ "$INTEL_DGPU" -gt 0 ] && can_toggle=true ;;
            4) [ "$INTEL_IGPU" -gt 0 ] && can_toggle=true ;;
            5) can_toggle=true ;; # nvtop always available
        esac
        
        if [ "$can_toggle" = true ]; then
            if [ "${SELECTIONS[$option]}" = true ]; then
                SELECTIONS[$option]=false
            else
                SELECTIONS[$option]=true
            fi
        else
            print_warning "This GPU is not available on your system"
            sleep 1
        fi
    fi
}

select_all() {
    # Only select available GPUs
    [ "$NVIDIA_DGPU" -gt 0 ] && SELECTIONS[0]=true
    [ "$AMD_DGPU" -gt 0 ] && SELECTIONS[1]=true
    [ "$AMD_IGPU" -gt 0 ] && SELECTIONS[2]=true
    [ "$INTEL_DGPU" -gt 0 ] && SELECTIONS[3]=true
    [ "$INTEL_IGPU" -gt 0 ] && SELECTIONS[4]=true
    SELECTIONS[5]=true  # nvtop always available
}

select_none() {
    for i in "${!SELECTIONS[@]}"; do
        SELECTIONS[$i]=false
    done
}

# ============================================
# POST-INSTALLATION FUNCTIONS
# ============================================

post_installation_checks() {
    print_section "Post-Installation Checks"
    
    if [ "$INSTALL_NVIDIA_DGPU" = true ]; then
        if command_exists nvidia-smi; then
            print_success "NVIDIA dGPU: nvidia-smi working"
            nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1
        else
            print_warning "nvidia-smi not available. DKMS may need manual intervention."
            print_status "Check status with: dkms status"
        fi
    fi
    
    if [ "$INSTALL_AMD_DGPU" = true ] || [ "$INSTALL_AMD_IGPU" = true ]; then
        if [ -f "/opt/rocm/bin/rocminfo" ]; then
            print_success "AMD GPU: ROCm installed"
        fi
    fi
    
    if [ "$INSTALL_INTEL_DGPU" = true ] || [ "$INSTALL_INTEL_IGPU" = true ]; then
        if command_exists intel_gpu_top; then
            print_success "Intel GPU: intel_gpu_top available"
        fi
    fi
    
    if command_exists nvtop; then
        print_success "nvtop: monitoring tool available"
    fi
}

show_next_steps() {
    print_section "Next Steps"
    
    echo -e "${GREEN}Testing commands:${NC}"
    [ "$INSTALL_NVIDIA_DGPU" = true ] && echo "  • nvidia-smi"
    [ "$INSTALL_AMD_DGPU" = true ] && echo "  • /opt/rocm/bin/rocminfo | grep Name"
    [ "$INSTALL_AMD_IGPU" = true ] && echo "  • /opt/rocm/bin/rocminfo | grep Name"
    [ "$INSTALL_INTEL_DGPU" = true ] && echo "  • clinfo | grep -i intel"
    [ "$INSTALL_INTEL_IGPU" = true ] && echo "  • intel_gpu_top"
    echo "  • nvtop"
    
    echo -e "\n${YELLOW}Important:${NC}"
    echo "  • Log out and back in for group changes to take effect"
    echo "  • Reboot to load all kernel modules"
    echo "  • For Docker GPU support: sudo systemctl restart docker"
    
    if [ "$INSTALL_NVIDIA_DGPU" = true ]; then
        echo -e "\n${CYAN}NVIDIA DKMS Troubleshooting:${NC}"
        echo "  If NVIDIA modules fail to load after reboot:"
        echo "  • Check status: dkms status"
        echo "  • Manual rebuild: sudo dkms autoinstall"
        echo "  • Check logs: sudo dkms install nvidia/$(pacman -Q nvidia-open-dkms | cut -d' ' -f2 | cut -d'-' -f1) -k $(uname -r)"
    fi
}

# ============================================
# MAIN FUNCTION
# ============================================

main() {
    # Print banner
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════╗"
    echo "║     GPU Detection & Installation Script    ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check prerequisites
    if ! command_exists lspci; then
        print_error "lspci command not found. Please install pciutils:"
        echo "  sudo pacman -S pciutils"
        exit 1
    fi
    
    if ! command_exists pacman; then
        print_error "This script is designed for Arch Linux with pacman"
        exit 1
    fi
    
    # Detect GPUs
    detect_gpus
    display_gpus
    
    # Check if any GPUs found
    if [ "$NVIDIA_DGPU" -eq 0 ] && [ "$AMD_DGPU" -eq 0 ] && [ "$AMD_IGPU" -eq 0 ] && \
       [ "$INTEL_DGPU" -eq 0 ] && [ "$INTEL_IGPU" -eq 0 ]; then
        print_warning "No supported GPUs detected"
        read -p "Install nvtop only? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            check_sudo
            setup_nvtop
            print_success "nvtop installed"
        fi
        exit 0
    fi
    
    # Initialize selections array (indices: 0=NVIDIA,1=AMD dGPU,2=AMD iGPU,3=Intel dGPU,4=Intel iGPU,5=nvtop)
    declare -g -a SELECTIONS=(false false false false false false)
    
    # Interactive menu loop
    while true; do
        show_menu
        
        read -p "Enter option: " choice
        echo ""
        
        case $choice in
            1)
                toggle_selection 0
                ;;
            2)
                toggle_selection 1
                ;;
            3)
                toggle_selection 2
                ;;
            4)
                toggle_selection 3
                ;;
            5)
                toggle_selection 4
                ;;
            6)
                toggle_selection 5
                ;;
            a|A)
                select_all
                ;;
            n|N)
                select_none
                ;;
            c|C)
                # Check if at least one option selected
                local any_selected=false
                for sel in "${SELECTIONS[@]}"; do
                    if [ "$sel" = true ]; then
                        any_selected=true
                        break
                    fi
                done
                
                if [ "$any_selected" = true ]; then
                    break
                else
                    print_warning "Please select at least one component to install"
                    sleep 1
                fi
                ;;
            q|Q)
                print_status "Installation cancelled"
                exit 0
                ;;
            *)
                print_warning "Invalid option: $choice"
                sleep 1
                ;;
        esac
    done
    
    # Map selections to installation variables
    INSTALL_NVIDIA_DGPU=${SELECTIONS[0]}
    INSTALL_AMD_DGPU=${SELECTIONS[1]}
    INSTALL_AMD_IGPU=${SELECTIONS[2]}
    INSTALL_INTEL_DGPU=${SELECTIONS[3]}
    INSTALL_INTEL_IGPU=${SELECTIONS[4]}
    INSTALL_NVTOP=${SELECTIONS[5]}
    
    # Show installation plan
    print_section "Installation Plan"
    [ "$INSTALL_NVIDIA_DGPU" = true ] && echo -e "${GREEN}• NVIDIA dGPU${NC}"
    [ "$INSTALL_AMD_DGPU" = true ] && echo -e "${RED}• AMD dGPU${NC}"
    [ "$INSTALL_AMD_IGPU" = true ] && echo -e "${RED}• AMD iGPU${NC}"
    [ "$INSTALL_INTEL_DGPU" = true ] && echo -e "${CYAN}• Intel dGPU${NC}"
    [ "$INSTALL_INTEL_IGPU" = true ] && echo -e "${CYAN}• Intel iGPU${NC}"
    [ "$INSTALL_NVTOP" = true ] && echo -e "${BLUE}• nvtop${NC}"
    
    # Final confirmation
    echo ""
    read -p "Proceed with installation? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_status "Installation cancelled"
        exit 0
    fi
    
    # Get sudo access
    check_sudo
    
    # Update package database
    print_status "Updating package database..."
    run_sudo pacman -Sy
    
    # Run selected installations (only if GPU is actually available)
    [ "$INSTALL_NVIDIA_DGPU" = true ] && [ "$NVIDIA_DGPU" -gt 0 ] && setup_nvidia_dgpu
    [ "$INSTALL_AMD_DGPU" = true ] && [ "$AMD_DGPU" -gt 0 ] && setup_amd_dgpu
    [ "$INSTALL_AMD_IGPU" = true ] && [ "$AMD_IGPU" -gt 0 ] && setup_amd_igpu
    [ "$INSTALL_INTEL_DGPU" = true ] && [ "$INTEL_DGPU" -gt 0 ] && setup_intel_dgpu
    [ "$INSTALL_INTEL_IGPU" = true ] && [ "$INTEL_IGPU" -gt 0 ] && setup_intel_igpu
    [ "$INSTALL_NVTOP" = true ] && setup_nvtop
    
    # Post-installation
    post_installation_checks
    show_next_steps
    
    print_success "Installation completed!"
}

# ============================================
# SCRIPT ENTRY POINT
# ============================================

# Run main function
main "$@"