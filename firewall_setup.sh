#!/bin/bash

echo "🧱 Firewall Setup Script"

if [ "$(id -u)" -ne 0 ]; then
    echo "🚫 This script must be run as root. Use sudo or log in as root."
    exit 1
fi

set -e

echo "Installing ufw..."
pacman -S --noconfirm ufw

echo "Enabling ufw service..."
systemctl enable ufw
systemctl start ufw

echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

echo "Allowing SSH (port 22) so you don't get locked out..."
ufw allow ssh

# Optional: allow common services (Uncomment if needed)
# ufw allow http        # Allow HTTP (port 80)
# ufw allow https       # Allow HTTPS (port 443)

echo "Enabling ufw firewall..."
ufw enable

echo "UFW status:"
ufw status verbose

echo "UFW setup completed successfully!"