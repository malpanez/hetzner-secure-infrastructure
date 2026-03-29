#!/bin/bash
# Full Deployment Script for Hetzner Secure Infrastructure
# Usage: ./scripts/deploy-full.sh [SERVER_IP]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_IP="${1}"

echo "🚀 Hetzner Secure Infrastructure Deployment"
echo "=============================================="
echo ""

# Check prerequisites
echo "✓ Checking prerequisites..."
command -v tofu >/dev/null 2>&1 || {
  echo "❌ OpenTofu not installed"
  exit 1
}
command -v ansible >/dev/null 2>&1 || {
  echo "❌ Ansible not installed"
  exit 1
}
echo ""

# Check environment variables
if [ -z "$HCLOUD_TOKEN" ]; then
  echo "❌ HCLOUD_TOKEN not set"
  echo "Export it: export HCLOUD_TOKEN='your-token'"
  exit 1
fi

if [ ! -f ~/.ssh/id_ed25519_sk.pub ]; then
  echo "❌ SSH key not found: ~/.ssh/id_ed25519_sk.pub"
  echo "Generate it first in Windows PowerShell:"
  echo "  ssh-keygen -t ed25519-sk -O resident -C 'miguel@hetzner' -f \$env:USERPROFILE\\.ssh\\id_ed25519_sk"
  exit 1
fi

# Deploy infrastructure with Terraform
echo "📦 Step 1: Deploying infrastructure with OpenTofu..."
cd "$PROJECT_ROOT/terraform/environments/production"

# Initialize
tofu init

# Plan
tofu plan -out=plan.out \
  -var="hcloud_token=$HCLOUD_TOKEN" \
  -var="ssh_public_key=$(cat ~/.ssh/id_ed25519_sk.pub)"

# Apply
tofu apply plan.out

# Get server IP
if [ -z "$SERVER_IP" ]; then
  SERVER_IP=$(tofu output -raw server_ipv4)
fi

echo ""
echo "✅ Infrastructure deployed! Server IP: $SERVER_IP"
echo ""

# Wait for server to be ready
echo "⏳ Waiting for server to be ready..."
sleep 30

# Test SSH connection
echo "🔑 Testing SSH connection..."
for i in {1..10}; do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 miguel@"${SERVER_IP}" "echo 'SSH works!'" 2>/dev/null; then
    echo "✅ SSH connection successful"
    break
  fi
  echo "   Attempt $i/10 failed, retrying..."
  sleep 10
done

# Run Ansible hardening
echo ""
echo "🔐 Step 2: Running Ansible hardening..."
cd "$PROJECT_ROOT/ansible"

# Update inventory
tofu output -json -state="$PROJECT_ROOT/terraform/environments/production/terraform.tfstate" >inventory/terraform-output.json

# Run playbook
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Server IP: $SERVER_IP"
echo ""
echo "📱 Next Steps:"
echo "1. SSH to server: ssh miguel@${SERVER_IP}"
echo "2. Run: sudo /usr/local/bin/setup-2fa-yubikey.sh miguel"
echo "3. In Windows PowerShell:"
echo "   ykman oath accounts add 'hetzner-miguel' YOUR_SECRET"
echo ""
echo "⚠️  IMPORTANT: Test SSH in a NEW terminal before closing current session!"
echo ""
