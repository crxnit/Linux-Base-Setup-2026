#!/bin/bash
# ============================================================================
# Linux Base Setup - Quick Install
# ============================================================================

set -e

REPO_URL="https://github.com/crxnit/Linux-Base-Setup-2026.git"
INSTALL_DIR="/opt/linux-base-setup"
TEMP_DIR=$(mktemp -d)

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

# Check if git is installed
if ! command -v git &>/dev/null; then
    echo "Installing git..."
    apt-get update -qq
    apt-get install -y git
fi

# Clone repository
echo "Downloading Linux Base Setup..."
cd "$TEMP_DIR"

if git clone "$REPO_URL" .; then
    echo "✓ Downloaded successfully"
else
    echo "ERROR: Failed to download from $REPO_URL"
    exit 1
fi

# Install to /opt
echo "Installing to $INSTALL_DIR..."
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
echo "Quick Start:"
echo "  1. Review configuration:"
echo "     nano $INSTALL_DIR/config/custom.conf.template"
echo ""
echo "  2. Copy and customize:"
echo "     cp $INSTALL_DIR/config/custom.conf.template \\"
echo "        $INSTALL_DIR/config/custom.conf"
echo ""
echo "  3. Preview changes (dry run):"
echo "     harden --dry-run"
echo ""
echo "  4. Run hardening:"
echo "     harden"
echo ""
echo "Documentation: $INSTALL_DIR/README.md"
echo "============================================"
