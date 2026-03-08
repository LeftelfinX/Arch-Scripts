#!/bin/bash

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check and request sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        print_warning "This script requires root privileges to manage the firewall."
        print_status "Attempting to restart with sudo..."
        
        # Re-run the script with sudo
        exec sudo bash "$0" "$@"
        
        # If exec fails, show error
        if [ $? -ne 0 ]; then
            print_error "Failed to gain root privileges. Please run with: sudo $0"
            exit 1
        fi
    fi
    
    print_success "Root privileges obtained."
}

# Function to install UFW
install_ufw() {
    print_status "Installing ufw..."
    if pacman -S --noconfirm ufw; then
        print_success "UFW installed successfully!"
    else
        print_error "Failed to install UFW"
        return 1
    fi
}

# Function to enable and start UFW service
enable_service() {
    print_status "Enabling ufw service..."
    systemctl enable ufw
    systemctl start ufw
    print_success "UFW service enabled and started!"
}

# Function to set default policies
set_default_policies() {
    print_status "Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing
    print_success "Default policies set: deny incoming, allow outgoing"
}

# Function to allow SSH
allow_ssh() {
    print_status "Allowing SSH (port 22)..."
    ufw allow ssh
    print_success "SSH allowed on port 22"
}

# Function to allow custom port
allow_custom_port() {
    read -p "Enter port number to allow: " port
    read -p "Enter protocol (tcp/udp/both) [default: both]: " protocol
    
    if [[ -z "$protocol" || "$protocol" == "both" ]]; then
        ufw allow $port
        print_success "Allowed port $port (TCP and UDP)"
    elif [[ "$protocol" == "tcp" || "$protocol" == "udp" ]]; then
        ufw allow $port/$protocol
        print_success "Allowed port $port/$protocol"
    else
        print_error "Invalid protocol. Please use tcp, udp, or both"
    fi
}

# Function to allow service by name
allow_service() {
    print_status "Available common services:"
    echo "1) HTTP (80)"
    echo "2) HTTPS (443)"
    echo "3) FTP (21)"
    echo "4) MySQL (3306)"
    echo "5) PostgreSQL (5432)"
    echo "6) SSH (22)"
    echo "7) Custom port"
    echo "8) Back to main menu"
    
    read -p "Select service to allow (1-8): " service_choice
    
    case $service_choice in
        1) ufw allow http && print_success "HTTP (80) allowed" ;;
        2) ufw allow https && print_success "HTTPS (443) allowed" ;;
        3) ufw allow ftp && print_success "FTP (21) allowed" ;;
        4) ufw allow 3306 && print_success "MySQL (3306) allowed" ;;
        5) ufw allow 5432 && print_success "PostgreSQL (5432) allowed" ;;
        6) ufw allow ssh && print_success "SSH (22) allowed" ;;
        7) allow_custom_port ;;
        8) return ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Function to deny/remove a rule
remove_rule() {
    print_status "Current rules:"
    ufw status numbered
    
    read -p "Enter rule number to delete (or 0 to cancel): " rule_num
    
    if [[ "$rule_num" =~ ^[0-9]+$ ]] && [ "$rule_num" -gt 0 ]; then
        echo "y" | ufw delete $rule_num
        print_success "Rule $rule_num deleted"
    elif [ "$rule_num" -eq 0 ]; then
        return
    else
        print_error "Invalid rule number"
    fi
}

# Function to enable firewall
enable_firewall() {
    print_status "Enabling ufw firewall..."
    echo "y" | ufw enable
    print_success "UFW firewall enabled!"
}

# Function to disable firewall
disable_firewall() {
    print_warning "Are you sure you want to disable the firewall? (y/N)"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        ufw disable
        print_warning "UFW firewall disabled"
    else
        print_status "Disable cancelled"
    fi
}

# Function to show status
show_status() {
    print_status "UFW Status:"
    ufw status verbose
}

# Function to reset firewall
reset_firewall() {
    print_warning "This will reset all firewall rules to default. Are you sure? (y/N)"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "y" | ufw reset
        print_success "UFW has been reset"
    else
        print_status "Reset cancelled"
    fi
}

# Function to check if UFW is installed
check_ufw_installed() {
    if ! command -v ufw &> /dev/null; then
        print_warning "UFW is not installed."
        read -p "Would you like to install it now? (y/N): " install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            install_ufw
        else
            return 1
        fi
    fi
    return 0
}

# Function to add custom rule
add_custom_rule() {
    echo "Custom Rule Options:"
    echo "1) Allow port"
    echo "2) Deny port"
    echo "3) Allow from IP"
    echo "4) Deny from IP"
    echo "5) Allow from IP to port"
    echo "6) Back to main menu"
    
    read -p "Select rule type (1-6): " rule_type
    
    case $rule_type in
        1)
            read -p "Enter port to allow: " port
            ufw allow $port
            print_success "Allowed port $port"
            ;;
        2)
            read -p "Enter port to deny: " port
            ufw deny $port
            print_success "Denied port $port"
            ;;
        3)
            read -p "Enter IP address to allow: " ip
            ufw allow from $ip
            print_success "Allowed all traffic from $ip"
            ;;
        4)
            read -p "Enter IP address to deny: " ip
            ufw deny from $ip
            print_success "Denied all traffic from $ip"
            ;;
        5)
            read -p "Enter IP address: " ip
            read -p "Enter port number: " port
            ufw allow from $ip to any port $port
            print_success "Allowed $ip to access port $port"
            ;;
        6)
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
}

# Main menu function
show_menu() {
    clear
    echo "========================================"
    echo "        🧱 UFW Firewall Manager        "
    echo "========================================"
    echo "1) Install UFW"
    echo "2) Enable UFW service"
    echo "3) Set default policies"
    echo "4) Allow SSH (port 22)"
    echo "5) Allow service/port"
    echo "6) Add custom rule"
    echo "7) Remove rule"
    echo "8) Enable firewall"
    echo "9) Disable firewall"
    echo "10) Show firewall status"
    echo "11) Reset firewall"
    echo "12) Full automated setup"
    echo "13) Exit"
    echo "========================================"
}

# Function for full automated setup
full_setup() {
    print_status "Starting full automated setup..."
    install_ufw
    enable_service
    set_default_policies
    allow_ssh
    enable_firewall
    show_status
    print_success "Full setup completed!"
}

# Main execution
main() {
    # Check for sudo privileges first
    check_sudo "$@"
    
    # Display welcome message
    echo ""
    echo "🧱 Welcome to UFW Firewall Manager"
    echo "========================================"
    
    # Check if UFW is installed (but don't force installation)
    if ! command -v ufw &> /dev/null; then
        print_warning "UFW is not installed on this system."
        echo "You can install it using option 1 from the menu."
        echo ""
    fi
    
    while true; do
        show_menu
        read -p "Enter your choice (1-13): " choice
        
        case $choice in
            1) install_ufw ;;
            2) enable_service ;;
            3) set_default_policies ;;
            4) allow_ssh ;;
            5) allow_service ;;
            6) add_custom_rule ;;
            7) remove_rule ;;
            8) enable_firewall ;;
            9) disable_firewall ;;
            10) show_status ;;
            11) reset_firewall ;;
            12) full_setup ;;
            13) 
                print_success "Thank you for using UFW Firewall Manager. Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please select 1-13"
                sleep 2
                ;;
        esac
        
        if [ "$choice" != "13" ]; then
            echo ""
            read -p "Press Enter to continue..."
        fi
    done
}

# Run the main function with all arguments
main "$@"