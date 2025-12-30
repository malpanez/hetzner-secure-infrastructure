#!/usr/bin/env bash
# Yubikey OATH-TOTP Setup for WSL2
# Configura Yubikey para almacenar códigos TOTP (en lugar de Google Authenticator app)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running in WSL2
check_wsl2() {
    if ! grep -qi microsoft /proc/version; then
        log_error "This script is designed for WSL2"
        exit 1
    fi
    log_info "Running in WSL2 ✓"
}

# Install yubikey-manager
install_ykman() {
    log_step "Installing Yubikey Manager..."

    if command -v ykman &> /dev/null; then
        log_info "Yubikey Manager already installed"
        ykman --version
        return 0
    fi

    sudo apt update
    sudo apt install -y yubikey-manager

    log_info "Yubikey Manager installed ✓"
}

# Configure udev rules for Yubikey access
setup_udev_rules() {
    log_step "Setting up udev rules for Yubikey..."

    RULES_FILE="/etc/udev/rules.d/70-yubikey.rules"

    if [[ -f "$RULES_FILE" ]]; then
        log_info "Udev rules already exist"
        return 0
    fi

    log_info "Creating udev rules..."
    sudo tee "$RULES_FILE" > /dev/null <<'EOF'
# Yubico YubiKey
SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", MODE="0660", GROUP="plugdev", TAG+="uaccess"

# Yubico YubiKey II
SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0010|0110|0111|0114|0116|0401|0403|0405|0407|0410", MODE="0660", GROUP="plugdev", TAG+="uaccess"
EOF

    # Add user to plugdev group
    if ! groups | grep -q plugdev; then
        log_info "Adding user to plugdev group..."
        sudo usermod -aG plugdev "$USER"
        log_warn "Group added. You may need to log out and back in for changes to take effect."
    fi

    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    log_info "Udev rules configured ✓"
}

# Detect Yubikey
detect_yubikey() {
    log_step "Detecting Yubikey..."

    if ! lsusb | grep -qi yubico; then
        log_error "Yubikey not detected via USB"
        echo ""
        echo "Please ensure:"
        echo "1. Yubikey is plugged into your Windows machine"
        echo "2. You ran in PowerShell (Admin):"
        echo "   usbipd attach --wsl --busid 4-2"
        echo ""
        echo "Check with: usbipd list"
        exit 1
    fi

    log_info "Yubikey detected via USB ✓"
    lsusb | grep -i yubico
    echo ""

    # Try to get Yubikey info
    if ! ykman info 2>/dev/null; then
        log_warn "Cannot read Yubikey info (permission issue?)"
        log_info "Attempting to fix permissions..."

        # Try to trigger udev again
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        sleep 2

        if ! ykman info; then
            log_error "Still cannot access Yubikey"
            log_warn "You may need to:"
            log_warn "1. Detach and reattach Yubikey (usbipd detach/attach)"
            log_warn "2. Log out and back in (group membership)"
            log_warn "3. Restart WSL (wsl --shutdown)"
            exit 1
        fi
    fi

    echo ""
    log_info "Yubikey accessible ✓"
}

# Configure OATH-TOTP
configure_oath() {
    log_step "Configuring OATH-TOTP..."

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  OATH-TOTP Setup for SSH 2FA"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # List existing accounts
    log_info "Current OATH accounts on Yubikey:"
    if ykman oath accounts list 2>/dev/null | grep -q .; then
        ykman oath accounts list
    else
        echo "  (none)"
    fi
    echo ""

    # Prompt for server name
    read -p "Enter server name (e.g., Hetzner-Staging): " SERVER_NAME
    if [[ -z "$SERVER_NAME" ]]; then
        log_error "Server name cannot be empty"
        exit 1
    fi

    # Prompt for TOTP secret
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Get TOTP Secret from Server"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "On your server, run:"
    echo "  google-authenticator"
    echo ""
    echo "Copy the SECRET KEY (base32, like: JBSWY3DPEHPK3PXP)"
    echo ""
    read -p "Paste SECRET KEY here: " SECRET_KEY

    if [[ -z "$SECRET_KEY" ]]; then
        log_error "Secret key cannot be empty"
        exit 1
    fi

    # Validate secret key format (base32)
    if ! [[ "$SECRET_KEY" =~ ^[A-Z2-7]+$ ]]; then
        log_warn "Secret key doesn't look like valid base32"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Aborted"
            exit 1
        fi
    fi

    # Ask about touch requirement
    echo ""
    read -p "Require touch to generate TOTP codes? [Y/n] " -n 1 -r
    echo
    TOUCH_FLAG=""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        TOUCH_FLAG="--touch"
        log_info "Touch will be required"
    else
        log_warn "Touch NOT required (less secure)"
    fi

    # Add OATH account to Yubikey
    log_info "Adding OATH account to Yubikey..."

    ACCOUNT_NAME="SSH:${SERVER_NAME}"

    if ykman oath accounts add "$ACCOUNT_NAME" \
        --oath-type TOTP \
        --algorithm SHA1 \
        --digits 6 \
        --period 30 \
        --issuer "SSH" \
        $TOUCH_FLAG \
        "$SECRET_KEY"; then

        echo ""
        log_info "✓ OATH account added successfully!"
        echo ""
        log_info "Account name: $ACCOUNT_NAME"

        # Test generating a code
        echo ""
        log_step "Testing code generation..."
        echo ""

        if [[ -n "$TOUCH_FLAG" ]]; then
            echo "Touch your Yubikey when it blinks..."
        fi

        CODE=$(ykman oath accounts code "$ACCOUNT_NAME" | awk '{print $NF}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ✓ SUCCESS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "TOTP Code: $CODE"
        echo ""
        echo "To generate codes in the future:"
        echo "  ykman oath accounts code \"$ACCOUNT_NAME\""
        echo ""

        # Create alias helper
        create_helper_script "$ACCOUNT_NAME"

    else
        log_error "Failed to add OATH account"
        exit 1
    fi
}

# Create helper script
create_helper_script() {
    local ACCOUNT_NAME="$1"

    log_step "Creating helper script..."

    HELPER_SCRIPT="$HOME/.local/bin/yubikey-totp"

    mkdir -p "$(dirname "$HELPER_SCRIPT")"

    cat > "$HELPER_SCRIPT" <<EOF
#!/usr/bin/env bash
# Yubikey TOTP Code Generator
# Auto-generated by yubikey-oath-setup.sh

if [[ \$# -eq 0 ]]; then
    # No arguments - generate code for default account
    ykman oath accounts code "$ACCOUNT_NAME" | awk '{print \$NF}'
else
    # Pass arguments to ykman
    ykman oath accounts "\$@"
fi
EOF

    chmod +x "$HELPER_SCRIPT"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "" >> "$HOME/.bashrc"
        echo "# Add local bin to PATH" >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        log_info "Added ~/.local/bin to PATH (restart shell to use)"
    fi

    log_info "Helper script created: $HELPER_SCRIPT"
    echo ""
    echo "You can now use:"
    echo "  yubikey-totp        # Generate TOTP code"
    echo "  yubikey-totp list   # List all accounts"
    echo "  yubikey-totp code   # Show all codes"
}

# Show usage instructions
show_usage() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📚 Usage Instructions"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "SSH Login Process:"
    echo ""
    echo "1. SSH to server:"
    echo "   ssh user@server"
    echo ""
    echo "2. SSH key authentication (passphrase if set)"
    echo ""
    echo "3. When prompted for Verification code:"
    echo "   - In another terminal: yubikey-totp"
    echo "   - OR: ykman oath accounts code"
    echo "   - Touch Yubikey (if required)"
    echo "   - Copy the 6-digit code"
    echo "   - Paste into SSH prompt"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "Useful commands:"
    echo ""
    echo "  List OATH accounts:"
    echo "    ykman oath accounts list"
    echo ""
    echo "  Generate code:"
    echo "    ykman oath accounts code <account-name>"
    echo ""
    echo "  Remove account:"
    echo "    ykman oath accounts delete <account-name>"
    echo ""
    echo "  Yubikey info:"
    echo "    ykman info"
    echo ""
}

# Main
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔑 Yubikey OATH-TOTP Setup for WSL2"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    check_wsl2
    install_ykman
    setup_udev_rules
    detect_yubikey
    configure_oath
    show_usage

    echo ""
    log_info "✓ Setup complete!"
    echo ""
}

main "$@"
