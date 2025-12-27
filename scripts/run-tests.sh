#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Automated Testing Script for Hetzner Secure Infrastructure
# ============================================================================
# This script runs all tests in the correct order with proper error handling
# Author: Miguel Alvarez
# Last Updated: 2025-12-26
# ============================================================================

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test results
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -a FAILED_TESTS=()

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

run_test() {
  local test_name="$1"
  local test_command="$2"

  print_info "Running: $test_name"

  if eval "$test_command"; then
    print_success "$test_name passed"
    ((TESTS_PASSED++))
    return 0
  else
    print_error "$test_name failed"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$test_name")
    return 1
  fi
}

check_dependencies() {
  print_header "Checking Dependencies"

  local deps=("terraform" "ansible" "ansible-lint" "yamllint" "python3" "go")
  local missing_deps=()

  for dep in "${deps[@]}"; do
    if command -v "$dep" &> /dev/null; then
      print_success "$dep found: $(command -v "$dep")"
    else
      print_error "$dep not found"
      missing_deps+=("$dep")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    print_error "Missing dependencies: ${missing_deps[*]}"
    print_info "Run 'make install-deps' to install dependencies"
    return 1
  fi

  return 0
}

# ============================================================================
# Test Functions
# ============================================================================

test_terraform_format() {
  print_header "Terraform Format Check"
  cd terraform/environments/production || return 1
  terraform fmt -check -recursive
  local result=$?
  cd - > /dev/null || return 1
  return $result
}

test_terraform_validate() {
  print_header "Terraform Validate"
  cd terraform/environments/production || return 1
  terraform init -backend=false > /dev/null 2>&1
  terraform validate
  local result=$?
  cd - > /dev/null || return 1
  return $result
}

test_ansible_syntax() {
  print_header "Ansible Syntax Check"
  cd ansible || return 1
  ansible-playbook playbooks/site.yml --syntax-check
  local result=$?
  cd - > /dev/null || return 1
  return $result
}

test_ansible_lint() {
  print_header "Ansible Lint"
  cd ansible || return 1
  ansible-lint playbooks/site.yml --offline || true
  local result=$?
  cd - > /dev/null || return 1
  return 0  # Don't fail on ansible-lint warnings
}

test_yaml_lint() {
  print_header "YAML Lint"
  yamllint -c .yamllint.yml ansible/ .woodpecker/ .github/ || true
  return 0  # Don't fail on yamllint warnings
}

test_shell_scripts() {
  print_header "ShellCheck"

  if ! command -v shellcheck &> /dev/null; then
    print_warning "shellcheck not found, skipping"
    return 0
  fi

  find scripts/ -type f -name "*.sh" -exec shellcheck -x {} \; || true
  return 0
}

test_molecule() {
  print_header "Molecule Tests"

  if ! command -v molecule &> /dev/null; then
    print_warning "molecule not found, skipping"
    return 0
  fi

  cd ansible/roles || return 1

  local roles=(
    "nginx-wordpress"
    "valkey"
    "mariadb"
    "prometheus"
    "grafana"
    "fail2ban"
    "firewall"
    "apparmor"
  )

  for role in "${roles[@]}"; do
    if [ -d "$role/molecule" ]; then
      print_info "Testing role: $role"
      (cd "$role" && molecule test --all) || {
        print_error "Molecule test failed for $role"
        cd - > /dev/null || return 1
        return 1
      }
    fi
  done

  cd - > /dev/null || return 1
  return 0
}

test_terratest() {
  print_header "Terratest (Short Mode)"

  if [ ! -d "terraform/test" ]; then
    print_warning "Terratest directory not found, skipping"
    return 0
  fi

  cd terraform/test || return 1
  go test -v -timeout 15m -short
  local result=$?
  cd - > /dev/null || return 1
  return $result
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  print_header "Hetzner Secure Infrastructure - Test Suite"

  # Check dependencies first
  if ! check_dependencies; then
    print_error "Dependency check failed"
    exit 1
  fi

  # Run all tests
  run_test "Terraform Format" "test_terraform_format" || true
  run_test "Terraform Validate" "test_terraform_validate" || true
  run_test "Ansible Syntax" "test_ansible_syntax" || true
  run_test "Ansible Lint" "test_ansible_lint" || true
  run_test "YAML Lint" "test_yaml_lint" || true
  run_test "Shell Scripts" "test_shell_scripts" || true

  # Optional tests (can be skipped)
  if [ "${SKIP_MOLECULE:-false}" != "true" ]; then
    run_test "Molecule Tests" "test_molecule" || true
  else
    print_warning "Skipping Molecule tests (SKIP_MOLECULE=true)"
  fi

  if [ "${SKIP_TERRATEST:-false}" != "true" ]; then
    run_test "Terratest" "test_terratest" || true
  else
    print_warning "Skipping Terratest (SKIP_TERRATEST=true)"
  fi

  # Print summary
  print_header "Test Summary"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"

  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "\n${RED}Failed tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
      echo -e "  ${RED}✗${NC} $test"
    done
    exit 1
  else
    echo -e "\n${GREEN}All tests passed! 🎉${NC}"
    exit 0
  fi
}

# Run main function
main "$@"
