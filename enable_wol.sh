#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then 
        print_message "Please run this script with sudo privileges" "$RED"
        print_message "Example: sudo $0" "$YELLOW"
        exit 1
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
        
        # Check if WoL is currently enabled
        if command -v ethtool &> /dev/null; then
            wol_status=$(ethtool "$interface" 2>/dev/null | grep "Wake-on" | grep -v "Supports" | awk '{print $2}')
            if [ "$wol_status" = "g" ]; then
                wol_display="$(print_message "WoL: ENABLED" "$GREEN")"
            else
                wol_display="$(print_message "WoL: DISABLED" "$RED")"
            fi
        else
            wol_display="WoL: Unknown"
        fi
        
        echo "$((i+1))) $interface - Status: $status - MAC: $mac - $wol_display"
    done
    
    echo "----------------------------------------"
    echo "0) Cancel/Exit"
    echo "----------------------------------------"
}

# Function to check if interface supports WoL
check_wol_support() {
    local interface=$1
    
    # Check if ethtool is installed
    if ! command -v ethtool &> /dev/null; then
        print_message "ethtool is not installed. Installing..." "$YELLOW"
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y ethtool
        elif command -v yum &> /dev/null; then
            yum install -y ethtool
        elif command -v dnf &> /dev/null; then
            dnf install -y ethtool
        else
            print_message "Could not install ethtool. Please install it manually." "$RED"
            exit 1
        fi
    fi
    
    # Check WoL support
    wol_support=$(ethtool "$interface" | grep "Supports Wake-on" | awk -F': ' '{print $2}')
    
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
    
    if command -v ethtool &> /dev/null; then
        current_wol=$(ethtool "$interface" 2>/dev/null | grep "Wake-on" | grep -v "Supports" | awk '{print $2}')
        if [ "$current_wol" = "g" ]; then
            print_message "✓ Wake-on-LAN is currently ENABLED on $interface" "$GREEN"
            return 0
        else
            print_message "✗ Wake-on-LAN is currently DISABLED on $interface" "$RED"
            return 1
        fi
    fi
}

# Function to enable WoL
enable_wol() {
    local interface=$1
    
    print_message "\nEnabling Wake-on-LAN for $interface..." "$BLUE"
    
    # Enable WoL using ethtool
    ethtool -s "$interface" wol g
    
    if [ $? -eq 0 ]; then
        print_message "✓ Wake-on-LAN enabled successfully for $interface" "$GREEN"
    else
        print_message "✗ Failed to enable Wake-on-LAN for $interface" "$RED"
        exit 1
    fi
    
    # Verify WoL is enabled
    current_wol=$(ethtool "$interface" | grep "Wake-on" | grep -v "Supports")
    print_message "Current WoL setting: $current_wol" "$YELLOW"
}

# Function to disable WoL
disable_wol() {
    local interface=$1
    
    print_message "\nDisabling Wake-on-LAN for $interface..." "$BLUE"
    
    # Disable WoL using ethtool
    ethtool -s "$interface" wol d
    
    if [ $? -eq 0 ]; then
        print_message "✓ Wake-on-LAN disabled successfully for $interface" "$GREEN"
    else
        print_message "✗ Failed to disable Wake-on-LAN for $interface" "$RED"
        exit 1
    fi
    
    # Verify WoL is disabled
    current_wol=$(ethtool "$interface" | grep "Wake-on" | grep -v "Supports")
    print_message "Current WoL setting: $current_wol" "$YELLOW"
}

# Function to create persistent service
create_persistent_service() {
    local interface=$1
    
    print_message "\nCreating persistent Wake-on-LAN service..." "$BLUE"
    
    # Create systemd service file
    cat > /etc/systemd/system/wol-enable.service << EOF
[Unit]
Description=Enable Wake-on-LAN for $interface
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s $interface wol g
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Also create a udev rule as backup
    cat > /etc/udev/rules.d/99-wol-enable.rules << EOF
# Enable Wake-on-LAN for $interface
ACTION=="add", SUBSYSTEM=="net", KERNEL=="$interface", RUN+="/usr/sbin/ethtool -s $interface wol g"
EOF

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable wol-enable.service
    systemctl start wol-enable.service
    
    if [ $? -eq 0 ]; then
        print_message "✓ Persistent Wake-on-LAN service created and enabled" "$GREEN"
    else
        print_message "✗ Failed to create persistent service" "$RED"
        exit 1
    fi
}

# Function to remove persistent service
remove_persistent_service() {
    local interface=$1
    
    print_message "\nRemoving persistent Wake-on-LAN configuration..." "$BLUE"
    
    # Stop and disable systemd service
    if [ -f /etc/systemd/system/wol-enable.service ]; then
        systemctl stop wol-enable.service 2>/dev/null
        systemctl disable wol-enable.service 2>/dev/null
        rm -f /etc/systemd/system/wol-enable.service
        systemctl daemon-reload
        print_message "✓ Systemd service removed" "$GREEN"
    fi
    
    # Remove udev rule
    if [ -f /etc/udev/rules.d/99-wol-enable.rules ]; then
        rm -f /etc/udev/rules.d/99-wol-enable.rules
        udevadm control --reload-rules
        udevadm trigger
        print_message "✓ Udev rule removed" "$GREEN"
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
    
    # Check if WoL is enabled
    if command -v ethtool &> /dev/null; then
        current_wol=$(ethtool "$interface" 2>/dev/null | grep "Wake-on" | grep -v "Supports")
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
    
    # Check service status
    if systemctl is-active --quiet wol-enable.service; then
        print_message "✓ Service is running" "$GREEN"
    else
        print_message "✗ Service is not running" "$RED"
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet wol-enable.service; then
        print_message "✓ Service is enabled at boot" "$GREEN"
    else
        print_message "✗ Service is not enabled at boot" "$RED"
    fi
    
    # Check udev rule
    if [ -f /etc/udev/rules.d/99-wol-enable.rules ]; then
        print_message "✓ Udev rule exists (backup)" "$GREEN"
    fi
    
    # Final WoL check
    final_wol=$(ethtool "$interface" | grep "Wake-on" | grep -v "Supports")
    print_message "Final WoL setting: $final_wol" "$YELLOW"
}

# Main script execution
main() {
    # Clear screen for better readability
    clear
    
    print_message "====================================" "$BLUE"
    print_message "   WAKE-ON-LAN MANAGEMENT SCRIPT" "$BLUE"
    print_message "====================================" "$BLUE"
    
    # Check for sudo
    check_sudo
    
    while true; do
        # List available interfaces
        list_interfaces
        
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
        
        clear
    done
}

# Run main function
main