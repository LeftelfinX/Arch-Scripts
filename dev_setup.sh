#!/bin/bash

echo "🔧 Software Packages Installer"

if [ "$(id -u)" -ne 0 ]; then
    echo "🚫 This script must be run as root. Use sudo or log in as root."
    exit 1
fi

# Update the system
echo
echo "🔄 Starting full system update..."
sudo pacman -Syyu

# Define the install buffer with descriptions
install_buffer=(
    # Core Development Tools
    base-devel # Essential build tools (gcc, make, binutils)
    git        # Version control system

    # Networking & Web Tools
    curl # Transfer data from URLs (APIs/downloads)
    wget # Alternative download utility

    # Python Development
    python # Python interpreter and standard library
    pyenv  # Python version manager (multi-version support)

    # Java Development
    jdk-openjdk # OpenJDK for Java applications

    # JavaScript/Node.js Development
    nodejs # JavaScript runtime (Node.js)
    npm    # Node.js package manager

    # Rust Development
    rust # Rust compiler and toolchain (cargo included)

    # Code Editors & IDEs
    visual-studio-code-bin # VS Code (official binary)
)

# Arrays for tracking status
installed=()
to_install=()

# Check installed packages
echo
echo "🔍 Checking installed packages..."

for pkg in "${install_buffer[@]}"; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
        installed+=("$pkg")
    else
        to_install+=("$pkg")
    fi
done

# Show already installed packages
if [ ${#installed[@]} -gt 0 ]; then
    echo
    echo "✅ Already installed:"
    printf ' - %s\n' "${installed[@]}"
fi

# Install missing packages
if [ ${#to_install[@]} -gt 0 ]; then
    echo
    echo "⬇️ Installing missing packages..."

    for pkg in "${to_install[@]}"; do
        echo "➡️ Installing $pkg..."
        if sudo pacman -S --noconfirm "$pkg"; then
            echo "✅ $pkg installed successfully."
        else
            echo "❌ Failed to install $pkg."
        fi
        echo
    done
else
    echo
    echo "🎉 All base packages are already installed. Nothing to install!"
fi
