#!/bin/bash
# ============================================================================
# Linux Base Setup - Quick Install
# ============================================================================

set -e

REPO_URL="https://github.com/crxnit/Linux-Base-Setup-2026.git"
INSTALL_DIR="/opt/linux-base-setup"

echo "============================================"
echo "  Linux Base Setup - Quick Install"
echo "============================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

# ============================================================================
# System Update and Essential Tools
# ============================================================================

echo "[1/4] Updating system packages..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo ""
echo "[2/4] Checking and installing essential tools..."

# List of essential tools needed for installation and script execution
ESSENTIAL_TOOLS=(
    "sudo"
    "curl"
    "git"
    "vim"
    "gnupg"
    "ca-certificates"
    "apt-transport-https"
)

# Check and install missing tools
MISSING_TOOLS=()
for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if ! dpkg -l "$tool" &>/dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo "Installing missing tools: ${MISSING_TOOLS[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING_TOOLS[@]}"
    echo "✓ Essential tools installed"
else
    echo "✓ All essential tools already installed"
fi

# Ensure sudo group exists and is configured
if ! getent group sudo &>/dev/null; then
    echo "Creating sudo group..."
    groupadd sudo
fi

# Add users to sudo group
# If SUDO_USER is set (script run via sudo), add that user
if [[ -n "$SUDO_USER" ]] && [[ "$SUDO_USER" != "root" ]]; then
    if ! groups "$SUDO_USER" 2>/dev/null | grep -q '\bsudo\b'; then
        echo "Adding user '$SUDO_USER' to sudo group..."
        usermod -aG sudo "$SUDO_USER"
        echo "✓ User '$SUDO_USER' added to sudo group"
    else
        echo "✓ User '$SUDO_USER' already in sudo group"
    fi
else
    # Running as root directly - add all regular users (UID >= 1000) to sudo group
    echo "Checking regular users for sudo access..."
    USERS_ADDED=0
    while IFS=: read -r username _ uid _ _ _ _; do
        if [[ $uid -ge 1000 ]] && [[ $uid -lt 65534 ]]; then
            if ! groups "$username" 2>/dev/null | grep -q '\bsudo\b'; then
                echo "Adding user '$username' to sudo group..."
                usermod -aG sudo "$username"
                ((USERS_ADDED++))
            fi
        fi
    done < /etc/passwd

    if [[ $USERS_ADDED -gt 0 ]]; then
        echo "✓ Added $USERS_ADDED user(s) to sudo group"
    else
        echo "✓ All regular users already have sudo access"
    fi
fi

# Create temp directory after tools are installed
TEMP_DIR=$(mktemp -d)

# Clone repository
echo ""
echo "[3/4] Downloading Linux Base Setup..."
cd "$TEMP_DIR"

if git clone --quiet "$REPO_URL" .; then
    echo "✓ Downloaded successfully"
else
    echo "ERROR: Failed to download from $REPO_URL"
    exit 1
fi

# Install to /opt
echo ""
echo "[4/4] Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp -r ./* "$INSTALL_DIR/"

# Set proper permissions
chmod +x "$INSTALL_DIR/harden.sh"
chmod +x "$INSTALL_DIR/modules/"*.sh
chmod 644 "$INSTALL_DIR/config/"*.conf
chmod 644 "$INSTALL_DIR/config/"*.template

# Create symlink
echo "Creating command symlink..."
ln -sf "$INSTALL_DIR/harden.sh" /usr/local/bin/harden

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "============================================"
echo "  Installation Complete!"
echo "============================================"
echo ""
echo "Installation Details:"
echo "  - Installation Directory: $INSTALL_DIR"
echo "  - Command: harden (symlinked to /usr/local/bin/harden)"
echo "  - Config Directory: $INSTALL_DIR/config/"
echo "  - Modules Directory: $INSTALL_DIR/modules/"
echo ""

# Show sudo activation instructions if users were added
if [[ -n "$SUDO_USER" ]] && [[ "$SUDO_USER" != "root" ]]; then
    echo "============================================"
    echo "  IMPORTANT: Activate sudo access"
    echo "============================================"
    echo ""
    echo "To use sudo without logging out, run:"
    echo "  exec su -l $SUDO_USER"
    echo ""
    echo "Or simply log out and back in."
    echo ""
fi

echo "Quick Start:"
echo "  1. Preview changes (dry run):"
echo "     sudo harden --dry-run"
echo ""
echo "  2. Run hardening:"
echo "     sudo harden"
echo ""
echo "  3. (Optional) Customize configuration first:"
echo "     sudo cp $INSTALL_DIR/config/custom.conf.template \\"
echo "            $INSTALL_DIR/config/custom.conf"
echo "     sudo nano $INSTALL_DIR/config/custom.conf"
echo ""
echo "Documentation: $INSTALL_DIR/README.md"
echo "============================================"
