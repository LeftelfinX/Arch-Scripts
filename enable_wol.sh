#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to ask for admin password
get_admin_password() {
    print_message "\nAdministrator privileges are required for this script." "$YELLOW"
    
    # Try sudo -v to check if user can get sudo
    if sudo -v &>/dev/null; then
        print_message "✓ Administrator access granted" "$GREEN"
        return 0
    else
        print_message "✗ Failed to get administrator privileges" "$RED"
        exit 1
    fi
}

# Function to run command with sudo
run_with_sudo() {
    local cmd="$1"
    local description="$2"
    
    print_message "→ $description..." "$BLUE"
    
    # Execute the command with sudo
    if eval "sudo $cmd"; then
        print_message "✓ $description completed successfully" "$GREEN"
        return 0
    else
        print_message "✗ Failed to $description" "$RED"
        return 1
    fi
}

# Function to install ethtool if needed
install_ethtool() {
    if ! command -v ethtool &> /dev/null; then
        print_message "ethtool is not installed. Installing..." "$YELLOW"
        if command -v apt-get &> /dev/null; then
            run_with_sudo "apt-get update && apt-get install -y ethtool" "install ethtool"
        elif command -v yum &> /dev/null; then
            run_with_sudo "yum install -y ethtool" "install ethtool"
        elif command -v dnf &> /dev/null; then
            run_with_sudo "dnf install -y ethtool" "install ethtool"
        elif command -v pacman &> /dev/null; then
            run_with_sudo "pacman -S --noconfirm ethtool" "install ethtool"
        else
            print_message "Could not install ethtool. Please install it manually." "$RED"
            return 1
        fi
    fi
    return 0
}

# Function to get WoL status for an interface
get_wol_status() {
    local interface=$1
    
    # Only try to get WoL status if ethtool is installed
    if command -v ethtool &> /dev/null; then
        # Use sudo to get the status, but don't show errors
        local wol_setting=$(sudo ethtool "$interface" 2>/dev/null | grep "Wake-on" | grep -v "Supports" | awk '{print $2}')
        
        if [ "$wol_setting" = "g" ]; then
            echo "ENABLED"
        elif [ "$wol_setting" = "d" ]; then
            echo "DISABLED"
        else
            echo "UNKNOWN"
        fi
    else
        echo "CHECKING..."
    fi
}

# Function to list available network interfaces
list_interfaces() {
    print_message "\nAvailable network interfaces:" "$BLUE"
    echo "----------------------------------------"
    
    # Get all network interfaces (excluding loopback and virtual/docker interfaces)
    interfaces=($(ip link show | grep -v "lo:" | grep -v "docker" | grep -v "veth" | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | cut -d'@' -f1))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        print_message "No network interfaces found!" "$RED"
        exit 1
    fi
    
    # Display interfaces with numbers
    for i in "${!interfaces[@]}"; do
        # Get interface details
        interface="${interfaces[$i]}"
        status=$(ip link show "$interface" | grep -q "UP" && echo "UP" || echo "DOWN")
        mac=$(ip link show "$interface" | grep -o -E '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | head -1)
        
        # Get WoL status
        wol_status=$(get_wol_status "$interface")
        
        # Color code the WoL status
        case $wol_status in
            "ENABLED")
                wol_display="$(print_message "WoL: ENABLED" "$GREEN")"
                ;;
            "DISABLED")
                wol_display="$(print_message "WoL: DISABLED" "$RED")"
                ;;
            "UNKNOWN")
                wol_display="$(print_message "WoL: UNKNOWN" "$YELLOW")"
                ;;
            "CHECKING...")
                wol_display="$(print_message "WoL: CHECKING..." "$CYAN")"
                ;;
        esac
        
        echo "$((i+1))) $interface - Status: $status - MAC: $mac - $wol_display"
    done
    
    echo "----------------------------------------"
    echo "0) Cancel/Exit"
    echo "----------------------------------------"
}

# Function to check if interface supports WoL
check_wol_support() {
    local interface=$1
    
    # Make sure ethtool is installed
    if ! install_ethtool; then
        return 1
    fi
    
    # Check WoL support
    wol_support=$(sudo ethtool "$interface" | grep "Supports Wake-on" | awk -F': ' '{print $2}')
    
    if [[ $wol_support == *"g"* ]]; then
        print_message "✓ Interface $interface supports Wake-on-LAN (magic packet)" "$GREEN"
        return 0
    else
        print_message "✗ Interface $interface does NOT support Wake-on-LAN" "$RED"
        return 1
    fi
}

# Function to check current WoL status
check_wol_status() {
    local interface=$1
    
    if ! install_ethtool; then
        return 1
    fi
    
    if command -v ethtool &> /dev/null; then
        current_wol=$(sudo ethtool "$interface" 2>/dev/null | grep "Wake-on" | grep -v "Supports" | awk '{print $2}')
        case $current_wol in
            "g")
                print_message "✓ Wake-on-LAN is currently ENABLED on $interface" "$GREEN"
                return 0
                ;;
            "d")
                print_message "✗ Wake-on-LAN is currently DISABLED on $interface" "$RED"
                return 1
                ;;
            *)
                print_message "? Wake-on-LAN status is UNKNOWN on $interface (Setting: $current_wol)" "$YELLOW"
                return 2
                ;;
        esac
    fi
}

# Function to enable WoL
enable_wol() {
    local interface=$1
    
    print_message "\nEnabling Wake-on-LAN for $interface..." "$BLUE"
    
    # Enable WoL using ethtool
    if run_with_sudo "ethtool -s $interface wol g" "enable Wake-on-LAN"; then
        # Verify WoL is enabled
        current_wol=$(sudo ethtool "$interface" | grep "Wake-on" | grep -v "Supports")
        print_message "Current WoL setting: $current_wol" "$YELLOW"
        return 0
    else
        return 1
    fi
}

# Function to disable WoL
disable_wol() {
    local interface=$1
    
    print_message "\nDisabling Wake-on-LAN for $interface..." "$BLUE"
    
    # Disable WoL using ethtool
    if run_with_sudo "ethtool -s $interface wol d" "disable Wake-on-LAN"; then
        # Verify WoL is disabled
        current_wol=$(sudo ethtool "$interface" | grep "Wake-on" | grep -v "Supports")
        print_message "Current WoL setting: $current_wol" "$YELLOW"
        return 0
    else
        return 1
    fi
}

# Function to create persistent service
create_persistent_service() {
    local interface=$1
    
    print_message "\nCreating persistent Wake-on-LAN service..." "$BLUE"
    
    # Create systemd service file using tee with sudo
    echo "[Unit]
Description=Enable Wake-on-LAN for $interface
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s $interface wol g
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/wol-enable.service > /dev/null

    # Also create a udev rule as backup
    echo "# Enable Wake-on-LAN for $interface
ACTION==\"add\", SUBSYSTEM==\"net\", KERNEL==\"$interface\", RUN+=\"/usr/sbin/ethtool -s $interface wol g\"" | sudo tee /etc/udev/rules.d/99-wol-enable.rules > /dev/null

    # Enable and start the service
    run_with_sudo "systemctl daemon-reload" "reload systemd"
    run_with_sudo "systemctl enable wol-enable.service" "enable service at boot"
    run_with_sudo "systemctl start wol-enable.service" "start service"
    
    print_message "✓ Persistent Wake-on-LAN service created and enabled" "$GREEN"
}

# Function to remove persistent service
remove_persistent_service() {
    local interface=$1
    
    print_message "\nRemoving persistent Wake-on-LAN configuration..." "$BLUE"
    
    # Stop and disable systemd service
    if [ -f /etc/systemd/system/wol-enable.service ]; then
        run_with_sudo "systemctl stop wol-enable.service" "stop service"
        run_with_sudo "systemctl disable wol-enable.service" "disable service"
        run_with_sudo "rm -f /etc/systemd/system/wol-enable.service" "remove service file"
        run_with_sudo "systemctl daemon-reload" "reload systemd"
    fi
    
    # Remove udev rule
    if [ -f /etc/udev/rules.d/99-wol-enable.rules ]; then
        run_with_sudo "rm -f /etc/udev/rules.d/99-wol-enable.rules" "remove udev rule"
        run_with_sudo "udevadm control --reload-rules" "reload udev rules"
        run_with_sudo "udevadm trigger" "trigger udev"
    fi
    
    print_message "✓ Persistent configuration removed" "$GREEN"
}

# Function to show menu options
show_action_menu() {
    local interface=$1
    
    print_message "\nWhat would you like to do with $interface?" "$PURPLE"
    echo "----------------------------------------"
    echo "1) Enable Wake-on-LAN (with persistence)"
    echo "2) Disable Wake-on-LAN (remove persistence)"
    echo "3) Check current WoL status"
    echo "4) Show MAC address only"
    echo "0) Cancel/Exit"
    echo "----------------------------------------"
    
    read -p "Select option (0-4): " action
    
    case $action in
        1)
            if check_wol_support "$interface"; then
                enable_wol "$interface"
                create_persistent_service "$interface"
                show_mac_address "$interface"
                verify_setup "$interface"
            fi
            ;;
        2)
            disable_wol "$interface"
            remove_persistent_service "$interface"
            print_message "\n✓ Wake-on-LAN has been disabled and all persistent configurations removed" "$GREEN"
            ;;
        3)
            check_wol_status "$interface"
            show_mac_address "$interface"
            ;;
        4)
            show_mac_address "$interface"
            ;;
        0)
            print_message "Operation cancelled. Exiting..." "$YELLOW"
            exit 0
            ;;
        *)
            print_message "Invalid option!" "$RED"
            show_action_menu "$interface"
            ;;
    esac
}

# Function to display MAC address
show_mac_address() {
    local interface=$1
    
    mac_address=$(ip link show "$interface" | grep -o -E '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | head -1)
    
    print_message "\n=== INTERFACE INFORMATION ===" "$BLUE"
    echo "Interface: $interface"
    echo "MAC Address: $mac_address"
    
    # Check if WoL is enabled (requires sudo)
    if command -v ethtool &> /dev/null; then
        current_wol=$(sudo ethtool "$interface" 2>/dev/null | grep "Wake-on" | grep -v "Supports")
        echo "WoL Status: $current_wol"
    fi
    
    echo ""
    print_message "To wake this computer from another device, use:" "$YELLOW"
    echo "wakeonlan $mac_address"
    echo "or"
    echo "etherwake $mac_address"
    echo ""
    print_message "Or use an online WoL service with this MAC address" "$YELLOW"
    
    # Copy to clipboard if possible
    if command -v xclip &> /dev/null; then
        echo -n "$mac_address" | xclip -selection clipboard
        print_message "✓ MAC address copied to clipboard!" "$GREEN"
    elif command -v pbcopy &> /dev/null; then
        echo -n "$mac_address" | pbcopy
        print_message "✓ MAC address copied to clipboard!" "$GREEN"
    elif command -v clip.exe &> /dev/null; then # WSL support
        echo -n "$mac_address" | clip.exe
        print_message "✓ MAC address copied to clipboard!" "$GREEN"
    fi
}

# Function to verify setup
verify_setup() {
    local interface=$1
    
    print_message "\nVerifying setup..." "$BLUE"
    
    # Check service status (requires sudo for systemctl)
    if sudo systemctl is-active --quiet wol-enable.service; then
        print_message "✓ Service is running" "$GREEN"
    else
        print_message "✗ Service is not running" "$RED"
    fi
    
    # Check if service is enabled
    if sudo systemctl is-enabled --quiet wol-enable.service; then
        print_message "✓ Service is enabled at boot" "$GREEN"
    else
        print_message "✗ Service is not enabled at boot" "$RED"
    fi
    
    # Check udev rule
    if [ -f /etc/udev/rules.d/99-wol-enable.rules ]; then
        print_message "✓ Udev rule exists (backup)" "$GREEN"
    fi
    
    # Final WoL check
    final_wol=$(sudo ethtool "$interface" | grep "Wake-on" | grep -v "Supports")
    print_message "Final WoL setting: $final_wol" "$YELLOW"
}

# Function to refresh interface list with accurate WoL status
refresh_display() {
    clear
    print_message "====================================" "$BLUE"
    print_message "   WAKE-ON-LAN MANAGEMENT SCRIPT" "$BLUE"
    print_message "====================================" "$BLUE"
    
    # Install ethtool if needed before showing status
    install_ethtool &>/dev/null
    
    list_interfaces
}

# Main script execution
main() {
    # Clear screen for better readability
    clear
    
    print_message "====================================" "$BLUE"
    print_message "   WAKE-ON-LAN MANAGEMENT SCRIPT" "$BLUE"
    print_message "====================================" "$BLUE"
    
    # Ask for admin password at runtime
    get_admin_password
    
    # Keep sudo alive in background
    while true; do sudo -v; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    
    # Install ethtool now so we can show accurate status
    install_ethtool
    
    while true; do
        # Refresh display with accurate WoL status
        refresh_display
        
        # Get user selection
        echo ""
        read -p "Select interface number (0 to cancel, 1-${#interfaces[@]}): " selection
        
        # Handle cancel option
        if [ "$selection" = "0" ]; then
            print_message "Operation cancelled. Exiting..." "$YELLOW"
            exit 0
        fi
        
        # Validate selection
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#interfaces[@]}" ]; then
            print_message "Invalid selection! Please try again." "$RED"
            sleep 2
            continue
        fi
        
        # Get selected interface
        selected_interface="${interfaces[$((selection-1))]}"
        
        print_message "\nSelected interface: $selected_interface" "$GREEN"
        
        # Show action menu for selected interface
        show_action_menu "$selected_interface"
        
        # Ask if user wants to do something else
        echo ""
        read -p "Do you want to manage another interface? (y/n): " another
        
        if [[ ! "$another" =~ ^[Yy]$ ]]; then
            print_message "\nThank you for using the Wake-on-LAN management script!" "$GREEN"
            break
        fi
    done
}

# Run main function
main