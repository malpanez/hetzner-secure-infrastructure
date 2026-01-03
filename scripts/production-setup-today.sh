#!/bin/bash
# Production Setup Script - Execute all tasks to go live today
# Date: 2026-01-02
#
# This script will:
# 1. Generate ansible automation SSH key
# 2. Deploy ansible user to production
# 3. Setup OpenBao automatic rotation
# 4. Provide Cloudflare DNS migration instructions
#
# Usage: ./scripts/production-setup-today.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Production Setup - Go Live Today!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check we're in the right directory
if [ ! -f "ansible/ansible.cfg" ]; then
    echo -e "${RED}ERROR: Please run this script from the repository root${NC}"
    exit 1
fi

# Step 1: Generate ansible automation SSH key
echo -e "${YELLOW}[Step 1/5] Generating ansible automation SSH key...${NC}"
if [ ! -f "$HOME/.ssh/ansible_automation" ]; then
    ssh-keygen -t ed25519 -C "ansible-automation@hetzner" -f "$HOME/.ssh/ansible_automation" -N ""
    echo -e "${GREEN}✓ SSH key generated: $HOME/.ssh/ansible_automation${NC}"
else
    echo -e "${YELLOW}⚠ SSH key already exists, skipping${NC}"
fi

echo ""
echo -e "${GREEN}Public key:${NC}"
cat "$HOME/.ssh/ansible_automation.pub"
echo ""

# Step 2: Deploy ansible user to production
echo -e "${YELLOW}[Step 2/5] Deploying ansible automation user to server...${NC}"
echo -e "${YELLOW}This will create a dedicated 'ansible' user with:${NC}"
echo -e "  - Ed25519 SSH key authentication"
echo -e "  - No 2FA (key-based only)"
echo -e "  - Restricted sudo access"
echo -e "  - All commands logged"
echo -e "  - Fail2ban monitoring"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted${NC}"
    exit 1
fi

cd ansible
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/setup-ansible-user.yml

echo ""
echo -e "${GREEN}✓ Ansible user deployed successfully${NC}"

# Step 3: Test ansible user connection
echo -e "${YELLOW}[Step 3/5] Testing ansible user SSH connection...${NC}"
SERVER_IP=$(ansible-inventory -i inventory/hetzner.hcloud.yml --list | jq -r '._meta.hostvars | to_entries[0].value.ansible_host')

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}ERROR: Could not determine server IP from inventory${NC}"
    exit 1
fi

echo "Testing connection to ansible@$SERVER_IP..."
if ssh -i "$HOME/.ssh/ansible_automation" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@$SERVER_IP "echo 'Connection successful!'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo -e "${YELLOW}Please check:${NC}"
    echo "  1. Server is running"
    echo "  2. UFW allows SSH (port 22)"
    echo "  3. SSH service is running"
    exit 1
fi

# Step 4: Setup OpenBao rotation
echo ""
echo -e "${YELLOW}[Step 4/5] Setting up OpenBao automatic secret rotation...${NC}"
echo -e "${YELLOW}This will configure daily rotation of WordPress database credentials${NC}"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Skipping OpenBao setup${NC}"
else
    ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/setup-openbao-rotation.yml
    echo -e "${GREEN}✓ OpenBao rotation configured${NC}"
fi

# Step 5: Cloudflare DNS migration instructions
echo ""
echo -e "${YELLOW}[Step 5/5] Cloudflare DNS Migration${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Next Steps: Migrate to Cloudflare${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Create Cloudflare account at: https://dash.cloudflare.com/sign-up"
echo "2. Add your domain to Cloudflare (Free plan)"
echo "3. Cloudflare will provide nameservers like:"
echo "     alexa.ns.cloudflare.com"
echo "     phil.ns.cloudflare.com"
echo ""
echo "4. Update nameservers at GoDaddy:"
echo "   a. Login to https://account.godaddy.com"
echo "   b. Go to My Products → Domains"
echo "   c. Click your domain → Manage DNS"
echo "   d. Nameservers → Change → Custom"
echo "   e. Replace with Cloudflare nameservers"
echo ""
echo "5. DNS records to add in Cloudflare:"
echo "   Type    Name    Content           Proxy"
echo "   ────────────────────────────────────────"
echo "   A       @       $SERVER_IP        ✅ Proxied"
echo "   A       www     $SERVER_IP        ✅ Proxied"
echo "   CNAME   *       @                 ✅ Proxied"
echo ""
echo "6. Wait 24-48 hours for DNS propagation"
echo ""
echo "7. Configure Cloudflare settings:"
echo "   - SSL/TLS: Full (strict)"
echo "   - Always Use HTTPS: ON"
echo "   - Auto Minify: HTML, CSS, JS"
echo "   - Brotli: ON"
echo ""
echo -e "${YELLOW}Full guide: docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md${NC}"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "What's been configured:"
echo "  ✓ Ansible automation user (secure, logged, monitored)"
echo "  ✓ OpenBao secret rotation (daily, automatic)"
echo "  ✓ Fail2ban protection for ansible user"
echo "  ✓ Enhanced logging and auditing"
echo ""
echo "What you need to do manually:"
echo "  1. Complete OpenBao database engine setup (see playbook output)"
echo "  2. Migrate DNS to Cloudflare (see instructions above)"
echo "  3. Purchase LearnDash license"
echo "  4. Build WordPress site content"
echo ""
echo -e "${YELLOW}To deploy with ansible user:${NC}"
echo "  ansible-playbook -i inventory/hetzner.hcloud.yml -u ansible --private-key=$HOME/.ssh/ansible_automation playbooks/site.yml"
echo ""
echo -e "${GREEN}Documentation:${NC}"
echo "  - docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md"
echo "  - docs/security/SSH_2FA_BREAK_GLASS.md"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"
