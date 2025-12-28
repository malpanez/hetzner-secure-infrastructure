#!/bin/bash
# 2FA Setup Script for Yubikey TOTP
# Usage: sudo /usr/local/bin/setup-2fa-yubikey.sh USERNAME

set -e

USER=$1

if [ -z "$USER" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

if [ ! -d "/home/$USER" ]; then
    echo "Error: User $USER does not exist"
    exit 1
fi

echo "========================================"
echo "Setting up 2FA for user: $USER"
echo "========================================"
echo ""

# Generate TOTP configuration
echo "Generating TOTP configuration..."
sudo -u $USER google-authenticator -t -d -f -r 3 -R 30 -w 3 -Q UTF8 -q

# Extract the secret for Yubikey
SECRET=$(sudo -u $USER head -1 /home/$USER/.google_authenticator)

echo ""
echo "=================================="
echo "✅ TOTP Setup Complete!"
echo "=================================="
echo ""
echo "🔑 Your TOTP Secret Key:"
echo "$SECRET"
echo ""
echo "📱 To add to your Yubikey (from Windows PowerShell):"
echo "   ykman oath accounts add \"hetzner-$USER\" $SECRET"
echo ""
echo "Alternative: Add to Google Authenticator app:"
echo "   Scan the QR code shown during interactive setup"
echo ""
echo "💾 Emergency Backup Codes:"
sudo -u $USER tail -5 /home/$USER/.google_authenticator
echo ""
echo "=================================="
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "=================================="
echo "1. Save the secret and backup codes securely"
echo "2. Test 2FA in a NEW terminal before closing this one"
echo "3. Keep your Yubikey safe - it's now required for access"
echo "4. If you lose your Yubikey, use emergency codes"
echo ""
echo "🧪 To test 2FA:"
echo "   1. Open a new terminal"
echo "   2. SSH to this server: ssh $USER@$(hostname -I | awk '{print $1}')"
echo "   3. You should be prompted for:"
echo "      - Yubikey touch (for FIDO2 key)"
echo "      - TOTP code (from Yubikey or app)"
echo ""
echo "=================================="
