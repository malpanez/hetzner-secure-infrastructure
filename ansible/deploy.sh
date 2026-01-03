#!/bin/bash
#
# Ansible Deployment Helper Script
# Executes ansible-playbook with automatic timestamped logging
#
# Usage:
#   ./deploy.sh [ansible-playbook arguments]
#
# Examples:
#   ./deploy.sh -u root playbooks/site.yml
#   ./deploy.sh -u root playbooks/site.yml --tags ssh,firewall
#   ./deploy.sh -u root playbooks/site.yml --check  # dry-run
#

set -e  # Exit on error

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="./logs/ansible-${TIMESTAMP}.log"

# Set environment variables for Ansible
export ANSIBLE_LOG_PATH="${LOG_FILE}"

# Display log file location
echo "=========================================="
echo "Ansible Deployment - $(date)"
echo "=========================================="
echo "Log file: ${LOG_FILE}"
echo "Command: ansible-playbook $@"
echo "=========================================="
echo ""

# Execute ansible-playbook with provided arguments
ansible-playbook "$@"

# Save exit code
EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Deployment finished: $(date)"
echo "Exit code: ${EXIT_CODE}"
echo "Log file: ${LOG_FILE}"
echo "=========================================="

# Create symlink to latest log
ln -sf "$(basename ${LOG_FILE})" logs/latest.log

exit ${EXIT_CODE}
