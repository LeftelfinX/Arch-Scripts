#!/bin/bash

# Git Setup Script for Arch Linux
# This script will install Git, configure user settings, and help you clone a private repository

set -e  # Exit on error

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
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

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
    print_error "This script is designed for Arch Linux only!"
    exit 1
fi

# Update system and install Git
print_message "Updating package database..."
sudo pacman -Sy

print_message "Installing Git..."
sudo pacman -S --noconfirm git

# Verify Git installation
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    print_success "Git installed successfully: $GIT_VERSION"
else
    print_error "Git installation failed!"
    exit 1
fi

# Configure Git username
print_message "Git user configuration"
echo ""

while true; do
    read -p "Enter your Git username (this will be visible in commits): " GIT_USERNAME
    if [ -n "$GIT_USERNAME" ]; then
        git config --global user.name "$GIT_USERNAME"
        print_success "Git username set to: $GIT_USERNAME"
        break
    else
        print_error "Username cannot be empty. Please try again."
    fi
done

# Configure Git email
while true; do
    read -p "Enter your Git email address: " GIT_EMAIL
    if [[ "$GIT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        git config --global user.email "$GIT_EMAIL"
        print_success "Git email set to: $GIT_EMAIL"
        break
    else
        print_error "Please enter a valid email address."
    fi
done

# Configure credential storage
echo ""
print_message "Credential storage configuration"
echo "Choose credential storage method:"
echo "1) cache - Store credentials in memory for a short time (default: 15 minutes)"
echo "2) store - Store credentials permanently in plain text on disk"
echo "3) libsecret - Store credentials securely using GNOME keyring/libsecret (recommended)"
echo ""

while true; do
    read -p "Select credential storage method [1-3] (default: 3): " CRED_CHOICE
    
    case ${CRED_CHOICE:-3} in
        1)
            git config --global credential.helper "cache --timeout=900"
            print_success "Credential helper set to 'cache' (15 minute timeout)"
            break
            ;;
        2)
            git config --global credential.helper store
            print_warning "Credentials will be stored in plain text at ~/.git-credentials"
            break
            ;;
        3)
            print_message "Installing libsecret for secure credential storage..."
            sudo pacman -S --noconfirm libsecret
            
            # Build and install git-credential-libsecret
            print_message "Building git-credential-libsecret..."
            cd /tmp
            if [ -d "git-credential-libsecret" ]; then
                rm -rf git-credential-libsecret
            fi
            
            git clone https://github.com/git-ecosystem/git-credential-libsecret.git
            cd git-credential-libsecret
            make
            sudo make install
            
            # Configure git to use libsecret
            git config --global credential.helper /usr/local/bin/git-credential-libsecret
            print_success "Credential helper set to 'libsecret' (secure storage)"
            cd ~
            break
            ;;
        *)
            print_error "Invalid choice. Please enter 1, 2, or 3."
            ;;
    esac
done

# Clone a private repository
echo ""
print_message "Private repository cloning"
echo "You'll need a GitHub Personal Access Token with 'repo' scope for private repositories."
echo "Create one at: https://github.com/settings/tokens"
echo ""

while true; do
    read -p "Enter the full GitHub repository URL (e.g., https://github.com/username/private-repo.git): " REPO_URL
    
    if [[ "$REPO_URL" =~ ^https://github\.com/.+/.+\.git$ ]]; then
        # Extract repo name for directory
        REPO_NAME=$(basename "$REPO_URL" .git)
        
        # Ask for token if using HTTPS
        if [[ "$REPO_URL" == https://* ]]; then
            echo ""
            print_message "For HTTPS cloning, you'll need to provide your GitHub Personal Access Token"
            echo "The token will be stored securely by your credential helper."
            
            read -sp "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
            echo ""
            
            if [ -n "$GITHUB_TOKEN" ]; then
                # Modify URL to include username (token will be used as password)
                # Extract username from URL or use token as username
                GITHUB_USERNAME=$(echo "$REPO_URL" | sed -E 's|https://github.com/([^/]+)/.*|\1|')
                AUTH_URL="https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$REPO_NAME.git"
                
                print_message "Cloning repository into ./$REPO_NAME..."
                
                # Clone with authentication
                if git clone "$AUTH_URL" "$REPO_NAME"; then
                    print_success "Repository cloned successfully!"
                    
                    # Remove credentials from URL in git config
                    cd "$REPO_NAME"
                    git remote set-url origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
                    print_message "Stripped credentials from repository remote URL."
                    
                    # Test that credentials are stored
                    print_message "Testing credential storage..."
                    if git ls-remote --heads origin > /dev/null 2>&1; then
                        print_success "Credentials stored successfully! You can now use git pull/push without re-entering your token."
                    else
                        print_warning "Credential storage test failed. You may need to enter your token again on next operation."
                    fi
                    
                    cd ~
                    break
                else
                    print_error "Failed to clone repository. Please check your token and repository URL."
                    # Clean up if partial clone occurred
                    rm -rf "$REPO_NAME" 2>/dev/null
                fi
            else
                print_error "Token cannot be empty. Please try again."
            fi
        else
            # SSH clone (should already work if SSH keys are set up)
            print_message "Cloning via SSH..."
            if git clone "$REPO_URL"; then
                print_success "Repository cloned successfully!"
                break
            else
                print_error "Failed to clone repository. Make sure your SSH keys are configured."
            fi
        fi
    else
        print_error "Please enter a valid GitHub repository URL (format: https://github.com/username/repo.git)"
    fi
done

# Display final configuration
echo ""
print_success "Git setup complete!"
echo ""
print_message "Current Git configuration:"
echo "----------------------------------------"
git config --global --list
echo "----------------------------------------"
echo ""
print_message "You can now use Git normally. Your credentials will be handled automatically."
print_message "To test your setup, try: cd $REPO_NAME && git pull"