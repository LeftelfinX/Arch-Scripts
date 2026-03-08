#!/bin/bash

echo "🔧 Software Development & Utilities Installer"
echo "=============================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "🚫 This script must be run as root. Use sudo or log in as root."
    exit 1
fi

# Update the system
echo
echo "🔄 Starting full system update..."
sudo pacman -Syyu --noconfirm

# Define the install buffer with descriptions
install_buffer=(
    # Core Development Tools
    base-devel      # Essential build tools (gcc, make, binutils, autoconf)
    git             # Version control system
    cmake           # Cross-platform build system generator
    make            # GNU make utility
    gcc             # GNU C/C++ compiler
    clang           # C/C++ compiler (LLVM)
    llvm            # LLVM compiler infrastructure
    pkg-config      # Manage compile/link flags for libraries

    # Networking & Web Tools
    curl            # Transfer data from URLs (APIs/downloads)
    wget            # Alternative download utility
    httpie          # Modern HTTP client (better than curl for APIs)
    nmap            # Network exploration tool
    net-tools       # Basic network tools (ifconfig, netstat)
    openssh         # SSH client and server
    rsync           # Fast file copying/syncing tool
    socat           # Multipurpose relay tool for socket connections

    # Python Development
    python          # Python interpreter and standard library
    python-pip      # Python package installer
    python-virtualenv # Python virtual environment tool
    python-setuptools # Python package development tools
    pyenv           # Python version manager (multi-version support)
    python-pytest   # Python testing framework
    python-black    # Python code formatter
    python-flake8   # Python linting tool
    python-mypy     # Python static type checker
    python-poetry   # Python dependency management
    jupyter-notebook # Interactive Python notebooks

    # Java Development
    jdk-openjdk     # OpenJDK for Java applications
    maven           # Java build automation tool
    gradle          # Advanced Java build system
    ant             # Java build tool
    scala           # Scala programming language
    sbt             # Scala build tool

    # JavaScript/Node.js Development
    nodejs          # JavaScript runtime (Node.js)
    npm             # Node.js package manager
    yarn            # Alternative Node.js package manager
    typescript      # Typed JavaScript superset
    deno            # Secure JavaScript/TypeScript runtime
    pnpm            # Fast, disk space efficient package manager

    # Rust Development
    rust            # Rust compiler and toolchain (cargo included)
    rustup          # Rust toolchain installer
    cargo           # Rust package manager (included with rust)

    # Go Development
    go              # Go programming language
    go-tools        # Additional Go tools

    # Ruby Development
    ruby            # Ruby programming language
    ruby-rdoc       # Ruby documentation generator
    ruby-irb        # Interactive Ruby shell
    gem             # Ruby package manager (included with ruby)

    # PHP Development
    php             # PHP programming language
    composer        # PHP dependency manager
    php-apache      # PHP module for Apache
    php-fpm         # PHP FastCGI Process Manager
    php-sqlite      # SQLite module for PHP
    php-pgsql       # PostgreSQL module for PHP
    php-mysql       # MySQL module for PHP

    # C# / .NET Development
    dotnet-sdk      # .NET Core SDK
    dotnet-runtime  # .NET Core runtime
    mono            # Cross-platform .NET implementation

    # Kotlin Development
    kotlin          # Kotlin programming language
    kotlin-native   # Kotlin Native compiler

    # Swift Development
    swift           # Swift programming language (from AUR typically)

    # Database Tools
    postgresql      # PostgreSQL database
    mysql           # MySQL database
    mariadb         # MariaDB database
    sqlite          # SQLite database engine
    sqlitebrowser   # GUI for SQLite databases
    mongodb         # MongoDB NoSQL database
    mongodb-tools   # MongoDB tools
    redis           # Redis key-value store
    dbeaver         # Universal database tool

    # Container & Virtualization
    docker          # Container platform
    docker-compose  # Docker orchestration tool
    podman          # Daemonless container engine
    kubectl         # Kubernetes CLI
    minikube        # Local Kubernetes
    vagrant         # VM environment manager
    virtualbox      # VirtualBox hypervisor
    qemu-full       # QEMU full virtualization
    virt-manager    # VM management GUI

    # Text Editors & IDEs
    vim             # Vim text editor
    neovim          # Modern Vim fork
    nano            # Simple text editor
    emacs           # GNU Emacs
    code            # VS Code (from official repos)
    intellij-idea-community-edition # IntelliJ IDEA CE
    pycharm-community-edition       # PyCharm CE
    eclipse-java    # Eclipse IDE for Java

    # Shell Enhancements
    zsh             # Z shell
    zsh-completions # Additional completions for Zsh
    zsh-syntax-highlighting # Syntax highlighting for Zsh
    zsh-autosuggestions # Fish-like autosuggestions
    fish            # Friendly interactive shell
    bash-completion # Bash completion support
    tmux            # Terminal multiplexer
    screen          # Terminal multiplexer

    # Terminal Utilities
    htop            # Interactive process viewer
    btop            # Resource-efficient process viewer
    glances         # Cross-platform monitoring
    nvtop           # GPU monitoring
    fastfetch       # System information display
    neofetch        # System information (legacy)
    duf             # Disk usage/free utility
    ncdu            # NCurses disk usage analyzer
    tree            # Directory tree viewer
    bat             # Cat clone with syntax highlighting
    exa             # Modern ls replacement
    fd              # Simple find alternative
    ripgrep         # Fast grep alternative
    fzf             # Command-line fuzzy finder
    jq              # JSON processor
    yq              # YAML processor
    tldr            # Simplified man pages
    tealdeer        # Fast tldr client
    thefuck         # Corrects previous command
    tig             # Git TUI browser

    # Compression Tools
    unzip           # ZIP extraction
    zip             # ZIP compression
    p7zip           # 7z compression
    unrar           # RAR extraction
    xz              # XZ compression
    tar             # Tape archive utility
    gzip            # GNU compression
    bzip2           # Bzip2 compression
    lz4             # LZ4 compression
    zstd            # Zstandard compression

    # Monitoring & Logging
    prometheus      # Monitoring system
    grafana         # Analytics platform
    node_exporter   # Prometheus node exporter
    netdata         # Real-time performance monitoring
    cockpit         # Web-based server management

    # Security Tools
    wireshark-qt    # Network protocol analyzer
    nmap            # Network scanner
    metasploit      # Penetration testing framework
    burpsuite       # Web security testing
    nikto           # Web server scanner
    hydra           # Password cracking tool
    john            # John the Ripper password cracker
    sqlmap          # SQL injection tool

    # Cloud & Infrastructure
    aws-cli         # AWS command line interface
    azure-cli       # Azure CLI
    google-cloud-sdk # Google Cloud SDK
    terraform       # Infrastructure as Code
    ansible         # IT automation tool
    packer          # Machine image builder
    vault           # Secrets management

    # Version Control Tools
    git-lfs         # Git Large File Storage
    git-flow        # Git extensions for branching
    github-cli      # GitHub CLI
    gitlab-runner   # GitLab CI runner

    # Documentation
    pandoc          # Document converter
    graphviz        # Graph visualization
    doxygen         # Documentation generator
    mkdocs          # Project documentation
    sphinx          # Python documentation generator

    # Multimedia Tools
    ffmpeg          # Multimedia framework
    imagemagick     # Image manipulation
    gimp            # Image editor
    inkscape        # Vector graphics editor
    blender         # 3D creation suite
    audacity        # Audio editor
    obs-studio      # Screen recording/streaming
    kdenlive        # Video editor
    vlc             # Media player
    mpv             # Video player

    # Office & Productivity
    libreoffice-fresh # Complete office suite
    thunderbird     # Email client
    firefox         # Web browser
    chromium        # Web browser
    keepassxc       # Password manager
    nextcloud-client # Nextcloud sync client

    # File Management
    ranger          # Terminal file manager
    mc              # Midnight Commander
    dolphin         # KDE file manager
    nautilus        # GNOME file manager
    rsync           # File sync/copy tool
    syncthing       # File synchronization

    # Fonts
    noto-fonts      # Google Noto fonts
    noto-fonts-emoji # Emoji fonts
    ttf-dejavu      # DejaVu fonts
    ttf-liberation  # Liberation fonts
    ttf-firacode-nerd # Fira Code with Nerd Fonts
    ttf-jetbrains-mono-nerd # JetBrains Mono Nerd Font
    adobe-source-code-pro-fonts # Source Code Pro

    # System Utilities
    cronie          # Cron daemon
    logrotate       # Log rotation utility
    sysstat         # System performance tools
    lm_sensors      # Hardware monitoring
    acpi            # ACPI information
    powertop        # Power consumption monitor
    hdparm          # Hard drive settings
    smartmontools   # S.M.A.R.T. monitoring
    usbutils        # USB utilities
    pciutils        # PCI utilities

    # Desktop Environments (selective)
    plasma-meta     # KDE Plasma desktop
    gnome           # GNOME desktop
    xfce4           # XFCE desktop
    i3-wm           # i3 window manager
    sway            # Sway Wayland compositor

    # Display Managers
    sddm            # KDE display manager
    gdm             # GNOME display manager
    lightdm         # Lightweight display manager

    # Audio
    pipewire        # Audio server
    pipewire-alsa   # ALSA support for PipeWire
    pipewire-pulse  # PulseAudio support for PipeWire
    wireplumber     # Session manager for PipeWire
    pavucontrol     # PulseAudio volume control
    alsa-utils      # ALSA utilities

    # Bluetooth
    bluez           # Bluetooth stack
    bluez-utils     # Bluetooth utilities
    blueman         # Bluetooth manager

    # Printing
    cups            # Printing system
    hplip           # HP printer drivers
    system-config-printer # Printer configuration GUI

    # Machine Learning & Data Science
    tensorflow      # Machine learning framework
    pytorch         # Deep learning framework
    jupyter         # Jupyter notebook (metapackage)
    pandas          # Python data analysis
    numpy           # Python numerical computing
    scipy           # Python scientific computing
    scikit-learn    # Python machine learning
    opencv          # Computer vision library
    cuda            # NVIDIA CUDA toolkit
    cudnn           # CUDA Deep Neural Network library
)

# Arrays for tracking status
installed=()
to_install=()

# Check installed packages
echo
echo "🔍 Checking installed packages..."
echo "================================="

# Show progress
total_packages=${#install_buffer[@]}
current=0

for pkg in "${install_buffer[@]}"; do
    # Skip if it's a comment line (starts with #)
    if [[ "$pkg" =~ ^#.* ]]; then
        continue
    fi
    
    current=$((current + 1))
    printf "\rProgress: [%d/%d] %-30s" "$current" "$total_packages" "$pkg"
    
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
        installed+=("$pkg")
    else
        to_install+=("$pkg")
    fi
done

echo -e "\n"

# Show already installed packages
if [ ${#installed[@]} -gt 0 ]; then
    echo "✅ Already installed packages:"
    echo "------------------------------"
    # Sort installed packages alphabetically
    IFS=$'\n' sorted_installed=($(sort <<<"${installed[*]}"))
    printf '   %s\n' "${sorted_installed[@]}"
    echo
fi

# Show packages to install
if [ ${#to_install[@]} -gt 0 ]; then
    echo "📦 Packages to install:"
    echo "------------------------"
    # Sort to install packages alphabetically
    IFS=$'\n' sorted_to_install=($(sort <<<"${to_install[*]}"))
    printf '   %s\n' "${sorted_to_install[@]}"
    echo
    echo "Total packages to install: ${#to_install[@]}"
    echo
else
    echo
    echo "🎉 All packages are already installed! Nothing to do."
    exit 0
fi

# Ask for confirmation
read -p "Proceed with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Install missing packages
if [ ${#to_install[@]} -gt 0 ]; then
    echo
    echo "⬇️ Installing missing packages..."
    echo "=================================="
    
    # Arrays for tracking results
    successfully_installed=()
    failed_installs=()
    skipped=()
    
    for pkg in "${to_install[@]}"; do
        echo "➡️ Installing $pkg..."
        if sudo pacman -S --noconfirm "$pkg" 2>/dev/null; then
            echo "✅ $pkg installed successfully."
            successfully_installed+=("$pkg")
        else
            # Check if it failed or if it's an AUR package
            if pacman -Si "$pkg" >/dev/null 2>&1; then
                echo "❌ Failed to install $pkg."
                failed_installs+=("$pkg")
            else
                echo "⚠️  $pkg not found in official repositories (may be in AUR)."
                skipped+=("$pkg")
            fi
        fi
        echo
    done
    
    # Final summary
    echo
    echo "📊 Installation Summary"
    echo "======================="
    
    if [ ${#successfully_installed[@]} -gt 0 ]; then
        echo "✅ Successfully installed (${#successfully_installed[@]}):"
        IFS=$'\n' sorted_success=($(sort <<<"${successfully_installed[*]}"))
        printf '   %s\n' "${sorted_success[@]}"
        echo
    fi
    
    if [ ${#failed_installs[@]} -gt 0 ]; then
        echo "❌ Failed to install (${#failed_installs[@]}):"
        IFS=$'\n' sorted_failed=($(sort <<<"${failed_installs[*]}"))
        printf '   %s\n' "${sorted_failed[@]}"
        echo
    fi
    
    if [ ${#skipped[@]} -gt 0 ]; then
        echo "⚠️  Not in official repos (may need AUR) (${#skipped[@]}):"
        IFS=$'\n' sorted_skipped=($(sort <<<"${skipped[*]}"))
        printf '   %s\n' "${sorted_skipped[@]}"
        echo
        echo "📝 Note: For AUR packages, install an AUR helper like yay or paru first:"
        echo "   git clone https://aur.archlinux.org/yay.git"
        echo "   cd yay && makepkg -si"
    fi
    
    # Overall status
    if [ ${#failed_installs[@]} -eq 0 ] && [ ${#skipped[@]} -eq 0 ]; then
        echo "🎉 All packages installed successfully!"
    elif [ ${#failed_installs[@]} -eq 0 ] && [ ${#skipped[@]} -gt 0 ]; then
        echo "⚠️  Installation completed with ${#skipped[@]} package(s) needing AUR."
    else
        echo "⚠️  Installation completed with ${#failed_installs[@]} failure(s) and ${#skipped[@]} AUR package(s)."
        exit 1
    fi
fi

# Optional: Install AUR helper if requested
echo
read -p "Do you want to install yay (AUR helper)? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! command -v yay &> /dev/null; then
        echo "📦 Installing yay from AUR..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay && makepkg -si --noconfirm
        cd -
        rm -rf /tmp/yay
        echo "✅ yay installed successfully!"
    else
        echo "✅ yay is already installed."
    fi
fi

echo
echo "✨ All operations completed!"
echo "📚 Remember to configure your development environment as needed."