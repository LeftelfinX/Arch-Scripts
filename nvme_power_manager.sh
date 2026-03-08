#!/bin/bash

# Simple NVMe Power Management Script
# Save as: nvme-powerman.sh
# Make executable: chmod +x nvme-powerman.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Configuration
SERVICE_FILE="/etc/systemd/system/nvme-power.service"

# Detect NVMe drives
get_drives() {
    DRIVES=()
    for ns in /dev/nvme[0-9]*n[0-9]; do
        [[ -e "$ns" ]] && DRIVES+=("$ns")
    done
}

# Get drive model
get_model() {
    local drive=$1
    local ctrl=$(echo "$drive" | sed 's/n[0-9]*$//')
    if command -v nvme &>/dev/null; then
        MODEL=$(sudo nvme id-ctrl "$ctrl" 2>/dev/null | grep "mn" | cut -d':' -f2- | tr -d ' ' | head -1)
    fi
    [[ -z "$MODEL" ]] && MODEL="Unknown"
}

# Get current power state
current_ps() {
    local ctrl=$1
    sudo nvme get-feature "$ctrl" -f 0x02 -H 2>/dev/null | grep "Power State" | awk '{print $4}' | grep -o '[0-9]\+' | head -1
}

# Get all temperatures
get_all_temperatures() {
    local drive=$1
    local ctrl=$(echo "$drive" | sed 's/n[0-9]*$//')
    
    echo -e "    ${BOLD}Temperatures:${NC}"
    
    # Get smart log and parse all temperature entries
    local smart_log=$(sudo nvme smart-log "$drive" 2>/dev/null)
    
    # Main temperature
    local main_temp=$(echo "$smart_log" | grep "^temperature" | grep -v ":" | head -1 | grep -o '[0-9]\+' | head -1)
    if [[ -n "$main_temp" ]]; then
        if [[ $main_temp -gt 60 ]]; then
            echo -e "      Main:     ${RED}${main_temp}°C${NC}"
        elif [[ $main_temp -gt 50 ]]; then
            echo -e "      Main:     ${YELLOW}${main_temp}°C${NC}"
        else
            echo -e "      Main:     ${GREEN}${main_temp}°C${NC}"
        fi
    fi
    
    # Composite temperature
    local composite_temp=$(echo "$smart_log" | grep "composite_temperature" | grep -o '[0-9]\+' | head -1)
    if [[ -n "$composite_temp" ]]; then
        if [[ $composite_temp -gt 60 ]]; then
            echo -e "      Composite: ${RED}${composite_temp}°C${NC}"
        elif [[ $composite_temp -gt 50 ]]; then
            echo -e "      Composite: ${YELLOW}${composite_temp}°C${NC}"
        else
            echo -e "      Composite: ${GREEN}${composite_temp}°C${NC}"
        fi
    fi
    
    # Sensor 1-8 temperatures
    for i in {1..8}; do
        local sensor_temp=$(echo "$smart_log" | grep -i "temperature_sensor_$i" | grep -o '[0-9]\+' | head -1)
        if [[ -n "$sensor_temp" ]]; then
            if [[ $sensor_temp -gt 60 ]]; then
                echo -e "      Sensor $i:  ${RED}${sensor_temp}°C${NC}"
            elif [[ $sensor_temp -gt 50 ]]; then
                echo -e "      Sensor $i:  ${YELLOW}${sensor_temp}°C${NC}"
            else
                echo -e "      Sensor $i:  ${GREEN}${sensor_temp}°C${NC}"
            fi
        fi
    done
    
    # If no detailed sensors found, just show the basic temperature
    if [[ -z "$composite_temp" && -z "$(echo "$smart_log" | grep -i "temperature_sensor")" ]]; then
        local basic_temp=$(echo "$smart_log" | grep -i "temperature" | head -1 | grep -o '[0-9]\+' | head -1)
        if [[ -n "$basic_temp" ]]; then
            if [[ $basic_temp -gt 60 ]]; then
                echo -e "      Current:  ${RED}${basic_temp}°C${NC}"
            elif [[ $basic_temp -gt 50 ]]; then
                echo -e "      Current:  ${YELLOW}${basic_temp}°C${NC}"
            else
                echo -e "      Current:  ${GREEN}${basic_temp}°C${NC}"
            fi
        fi
    fi
}

# Get controller info
get_controller_info() {
    local drive=$1
    local ctrl=$(echo "$drive" | sed 's/n[0-9]*$//')
    
    if command -v nvme &>/dev/null; then
        local fw=$(sudo nvme id-ctrl "$ctrl" 2>/dev/null | grep "fr" | head -1 | cut -d':' -f2- | tr -d ' ')
        if [[ -n "$fw" ]]; then
            echo -e "    Firmware: ${CYAN}$fw${NC}"
        fi
    fi
}

# Set all drives to max power saving
enable_powersave() {
    echo -e "${CYAN}Enabling maximum power saving for all NVMe drives...${NC}\n"
    
    # Install requirements
    if ! command -v nvme &>/dev/null; then
        echo "Installing nvme-cli..."
        if command -v apt &>/dev/null; then
            sudo apt install -y nvme-cli >/dev/null 2>&1
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm nvme-cli >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y nvme-cli >/dev/null 2>&1
        fi
    fi
    
    get_drives
    
    # Enable ASPM
    if [[ -f /sys/module/pcie_aspm/parameters/policy ]]; then
        echo "powersupersave" | sudo tee /sys/module/pcie_aspm/parameters/policy >/dev/null 2>&1 || \
        echo "powersave" | sudo tee /sys/module/pcie_aspm/parameters/policy >/dev/null 2>&1
    fi
    
    # Set each drive to deepest power state
    declare -A STATES
    for drive in "${DRIVES[@]}"; do
        ctrl=$(echo "$drive" | sed 's/n[0-9]*$//')
        get_model "$drive"
        
        # Get max PS from drive
        max_ps=$(sudo nvme id-ctrl "$ctrl" 2>/dev/null | grep -A50 "^ps " | grep -c "^ps" 2>/dev/null)
        max_ps=$((max_ps - 1))
        [[ $max_ps -lt 0 ]] && max_ps=3
        
        echo -e "  ${BOLD}$MODEL${NC}"
        
        # Try deepest first, fall back if needed
        for ((ps=max_ps; ps>=0; ps--)); do
            if sudo nvme set-feature "$ctrl" -f 0x02 -v "$ps" >/dev/null 2>&1; then
                STATES["$ctrl"]=$ps
                echo -e "    ${GREEN}✓${NC} Set to PS$ps"
                break
            fi
        done
        sleep 1
    done
    
    # Create service file
    echo -e "\n${CYAN}Creating startup service...${NC}"
    
    cat > /tmp/nvme-power.service << EOF
[Unit]
Description=NVMe Power Saving
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sleep 5 && \
    echo powersupersave > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || \
    echo powersave > /sys/module/pcie_aspm/parameters/policy 2>/dev/null$(for ctrl in "${!STATES[@]}"; do echo " && \\" && echo "    nvme set-feature $ctrl -f 0x02 -v ${STATES[$ctrl]} >/dev/null 2>&1"; done)'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    sudo mv /tmp/nvme-power.service "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable nvme-power.service >/dev/null 2>&1
    sudo systemctl start nvme-power.service 2>/dev/null
    
    echo -e "${GREEN}✓${NC} Service installed and started"
    echo -e "\n${GREEN}✅ Power saving enabled!${NC}"
}

# Show current status
show_status() {
    echo -e "${CYAN}NVMe Power Status${NC}\n"
    
    get_drives
    
    if [[ ${#DRIVES[@]} -eq 0 ]]; then
        echo -e "${RED}No NVMe drives found${NC}"
        return
    fi
    
    for drive in "${DRIVES[@]}"; do
        ctrl=$(echo "$drive" | sed 's/n[0-9]*$//')
        get_model "$drive"
        ps=$(current_ps "$ctrl")
        
        case $ps in
            0|1) state="${RED}Performance${NC}" ;;
            2|3) state="${YELLOW}Balanced${NC}" ;;
            4|5) state="${GREEN}Power Save${NC}" ;;
            *) state="${RED}Unknown${NC}" ;;
        esac
        
        echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${BOLD}$MODEL${NC}"
        echo -e "    ${BOLD}Drive:${NC} $drive"
        echo -e "    ${BOLD}Controller:${NC} $ctrl"
        echo -e "    ${BOLD}Power State:${NC} PS$ps - $state"
        
        # Show controller info
        get_controller_info "$drive"
        
        # Show all temperatures
        get_all_temperatures "$drive"
        
        # Show additional smart info
        if command -v nvme &>/dev/null; then
            local pcycles=$(sudo nvme smart-log "$drive" 2>/dev/null | grep "power_cycles" | grep -o '[0-9]\+' | head -1)
            local phours=$(sudo nvme smart-log "$drive" 2>/dev/null | grep "power_on_hours" | grep -o '[0-9]\+' | head -1)
            
            if [[ -n "$pcycles" ]]; then
                echo -e "    ${BOLD}Power Cycles:${NC} $pcycles"
            fi
            if [[ -n "$phours" ]]; then
                echo -e "    ${BOLD}Power On Hours:${NC} $phours"
            fi
        fi
        echo
    done
    
    # ASPM status
    if [[ -f /sys/module/pcie_aspm/parameters/policy ]]; then
        policy=$(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null | awk '{print $2}' | tr -d '[]')
        echo -e "${BOLD}ASPM Policy:${NC} ${CYAN}$policy${NC}"
    fi
    
    # Service status
    if systemctl is-enabled nvme-power.service &>/dev/null; then
        echo -e "${BOLD}Service:${NC} ${GREEN}Enabled${NC}"
        if systemctl is-active nvme-power.service &>/dev/null; then
            echo -e "${BOLD}Status:${NC} ${GREEN}Active${NC}"
        else
            echo -e "${BOLD}Status:${NC} ${YELLOW}Inactive${NC} (runs at boot)"
        fi
    else
        echo -e "${BOLD}Service:${NC} ${RED}Disabled${NC}"
    fi
}

# Remove everything
remove_config() {
    echo -e "${YELLOW}Removing NVMe power configuration...${NC}\n"
    
    # Stop and remove service
    sudo systemctl stop nvme-power.service 2>/dev/null
    sudo systemctl disable nvme-power.service 2>/dev/null
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    
    # Reset drives to PS0
    get_drives
    for drive in "${DRIVES[@]}"; do
        ctrl=$(echo "$drive" | sed 's/n[0-9]*$//')
        get_model "$drive"
        sudo nvme set-feature "$ctrl" -f 0x02 -v 0 >/dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} $MODEL reset to PS0"
    done
    
    # Reset ASPM
    if [[ -f /sys/module/pcie_aspm/parameters/policy ]]; then
        echo "default" | sudo tee /sys/module/pcie_aspm/parameters/policy >/dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} ASPM reset to default"
    fi
    
    echo -e "\n${GREEN}✅ Configuration removed${NC}"
}

# Main menu
while true; do
    clear
    echo -e "${CYAN}════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}    NVMe POWER MANAGER${NC}"
    echo -e "${CYAN}════════════════════════════════════${NC}"
    echo
    echo -e "${GREEN}1${NC}. ⚡ ENABLE POWER SAVING (Deep sleep for all)"
    echo -e "${GREEN}2${NC}. 📊 SHOW STATUS (Temperatures & Details)"
    echo -e "${GREEN}3${NC}. 🗑️  REMOVE CONFIGURATION"
    echo -e "${GREEN}4${NC}. 👋 EXIT"
    echo
    echo -e "${CYAN}════════════════════════════════════${NC}"
    
    get_drives 2>/dev/null
    echo -e "${BOLD}Found:${NC} ${#DRIVES[@]} NVMe drive(s)"
    echo
    
    read -p "Choice [1-4]: " choice
    
    case $choice in
        1) 
            enable_powersave
            echo -e "\n${DIM}Press Enter to continue${NC}"
            read
            ;;
        2) 
            show_status
            echo -e "\n${DIM}Press Enter to continue${NC}"
            read
            ;;
        3) 
            remove_config
            echo -e "\n${DIM}Press Enter to continue${NC}"
            read
            ;;
        4) 
            clear
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}Invalid choice${NC}"
            sleep 1
            ;;
    esac
done