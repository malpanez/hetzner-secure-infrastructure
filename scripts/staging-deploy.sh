#!/usr/bin/env bash
# Quick Staging Deployment Script
# Deploy and test infrastructure on Hetzner Cloud
# Cost: ~€0.008/hour (~€0.02 for 2-3 hours of testing)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."

    # Check terraform
    if ! command -v terraform &> /dev/null; then
        log_error "terraform not found. Install: https://www.terraform.io/downloads"
        exit 1
    fi

    # Check ansible
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "ansible not found. Install: pip install ansible"
        exit 1
    fi

    # Check HCLOUD_TOKEN
    if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
        log_error "HCLOUD_TOKEN environment variable not set"
        echo "Export it: export HCLOUD_TOKEN='your-token'"
        exit 1
    fi

    # Check tfvars exists
    if [[ ! -f "${TERRAFORM_DIR}/terraform.staging.tfvars" ]]; then
        log_error "terraform.staging.tfvars not found"
        echo "Copy example: cp ${TERRAFORM_DIR}/terraform.staging.tfvars.example ${TERRAFORM_DIR}/terraform.staging.tfvars"
        echo "Then edit with your values"
        exit 1
    fi

    log_info "✓ All requirements met"
}

terraform_deploy() {
    log_info "Deploying infrastructure with Terraform..."

    cd "${TERRAFORM_DIR}"

    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init
    fi

    # Validate
    log_info "Validating Terraform configuration..."
    terraform validate

    # Plan
    log_info "Planning infrastructure changes..."
    terraform plan -var-file="terraform.staging.tfvars" -out=staging.tfplan

    # Apply
    echo ""
    log_warn "About to deploy to Hetzner Cloud"
    log_warn "Estimated cost: €0.008/hour (~€0.02 for 2-3 hours)"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi

    terraform apply staging.tfplan

    # Get server IP
    SERVER_IP=$(terraform output -raw server_ipv4)
    log_info "Server deployed at: ${SERVER_IP}"

    # Wait for SSH to be ready
    log_info "Waiting 60 seconds for server to boot..."
    sleep 60

    log_info "✓ Terraform deployment complete"
}

ansible_deploy() {
    log_info "Deploying configuration with Ansible..."

    cd "${ANSIBLE_DIR}"

    # Check Galaxy requirements
    if [[ ! -d "${HOME}/.ansible/collections/ansible_collections/prometheus/prometheus" ]]; then
        log_info "Installing Ansible Galaxy requirements..."
        ansible-galaxy install -r requirements.yml --force
    fi

    # Check vault
    if [[ ! -f "inventory/group_vars/all/vault.yml" ]]; then
        log_warn "Ansible vault not found"
        echo "Create it: ansible-vault create inventory/group_vars/all/vault.yml"
        echo "Or run Ansible manually later"
        return 1
    fi

    # Test connectivity
    log_info "Testing connectivity to staging server..."
    if ! ansible all -i inventory/hetzner.yml -m ping &> /dev/null; then
        log_error "Cannot connect to staging server"
        echo "Check SSH key and firewall rules"
        return 1
    fi

    # Deploy
    log_info "Running Ansible playbook (this takes ~10-15 minutes)..."

    # Ask which playbook
    echo ""
    echo "Which playbook to run?"
    echo "1) wordpress-only.yml (recommended for quick testing)"
    echo "2) site.yml (full deployment with monitoring)"
    read -p "Choice [1-2]: " -n 1 -r
    echo

    if [[ $REPLY == "2" ]]; then
        PLAYBOOK="playbooks/site.yml"
    else
        PLAYBOOK="playbooks/wordpress-only.yml"
    fi

    ansible-playbook -i inventory/hetzner.yml "${PLAYBOOK}" --ask-vault-pass

    log_info "✓ Ansible deployment complete"
}

verify_deployment() {
    log_info "Verifying deployment..."

    cd "${TERRAFORM_DIR}"
    SERVER_IP=$(terraform output -raw server_ipv4)

    # Test HTTP
    log_info "Testing WordPress (HTTP)..."
    if curl -s -o /dev/null -w "%{http_code}" "http://${SERVER_IP}" | grep -q "200\|301\|302"; then
        log_info "✓ WordPress is responding"
    else
        log_warn "WordPress may not be fully configured yet"
    fi

    # Show connection info
    echo ""
    echo "=========================================="
    log_info "Deployment Information"
    echo "=========================================="
    echo "Server IP:     ${SERVER_IP}"
    echo "SSH:           ssh miguel@${SERVER_IP}"
    echo "WordPress:     http://${SERVER_IP}"
    echo "WP Admin:      http://${SERVER_IP}/wp-admin"
    echo ""
    echo "Cost per hour: €0.008"
    echo "Cost per day:  €0.19"
    echo "=========================================="
    echo ""

    log_info "Next steps:"
    echo "1. Open http://${SERVER_IP} in browser"
    echo "2. Complete WordPress installation"
    echo "3. Test all functionality"
    echo "4. When done: ./scripts/staging-destroy.sh"
}

# Main
main() {
    log_info "Hetzner Staging Deployment"
    echo "=========================================="

    check_requirements
    terraform_deploy

    echo ""
    read -p "Deploy Ansible now? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ansible_deploy
        verify_deployment
    else
        log_info "Terraform deployed. Run Ansible manually:"
        echo "cd ansible"
        echo "ansible-playbook -i inventory/hetzner.yml playbooks/wordpress-only.yml --ask-vault-pass"
    fi
}

main "$@"
