#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Validation Script - Quick Pre-commit Checks
# ============================================================================
# Runs fast validation checks before committing
# Author: Miguel Alvarez
# Last Updated: 2025-12-26
# ============================================================================

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Track failures
FAILED=0

# ============================================================================
# Validation Checks
# ============================================================================

validate_terraform() {
  print_header "Validating Terraform"

  print_info "Checking format..."
  if terraform -chdir=terraform/environments/production fmt -check -recursive; then
    print_success "Terraform format OK"
  else
    print_error "Terraform format check failed"
    ((FAILED++))
  fi

  print_info "Validating configuration..."
  if terraform -chdir=terraform/environments/production init -backend=false > /dev/null 2>&1 && \
     terraform -chdir=terraform/environments/production validate > /dev/null; then
    print_success "Terraform validation OK"
  else
    print_error "Terraform validation failed"
    ((FAILED++))
  fi
}

validate_ansible() {
  print_header "Validating Ansible"

  print_info "Checking syntax..."
  # Ignore warnings about collection versions, only check for syntax errors
  if ansible-playbook ansible/playbooks/site.yml --syntax-check 2>&1 | grep -q "ERROR"; then
    print_error "Ansible syntax check failed"
    ((FAILED++))
  else
    print_success "Ansible syntax OK"
  fi
}

validate_yaml() {
  print_header "Validating YAML"

  if command -v yamllint &> /dev/null; then
    if yamllint -c .yamllint.yml ansible/ .woodpecker/ .github/ > /dev/null 2>&1; then
      print_success "YAML lint OK"
    else
      print_error "YAML lint found issues (warnings ignored)"
    fi
  else
    print_info "yamllint not found, skipping"
  fi
}

validate_markdown() {
  print_header "Validating Markdown"

  if command -v markdownlint &> /dev/null; then
    if markdownlint -c .markdownlint.json *.md docs/*.md > /dev/null 2>&1; then
      print_success "Markdown lint OK"
    else
      print_error "Markdown lint found issues (warnings ignored)"
    fi
  else
    print_info "markdownlint not found, skipping"
  fi
}

check_secrets() {
  print_header "Checking for Secrets"

  if command -v gitleaks &> /dev/null; then
    if gitleaks detect --no-git --verbose > /dev/null 2>&1; then
      print_success "No secrets detected"
    else
      print_error "Potential secrets found!"
      ((FAILED++))
    fi
  else
    print_info "gitleaks not found, skipping"
  fi
}

# ============================================================================
# Main
# ============================================================================

main() {
  print_header "Quick Validation Checks"

  validate_terraform
  validate_ansible
  validate_yaml
  validate_markdown
  check_secrets

  echo ""
  if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  All validations passed! ✓${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
  else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  $FAILED validation(s) failed! ✗${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
  fi
}

main "$@"
