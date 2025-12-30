#!/usr/bin/env bash
# Destroy Staging Infrastructure
# Clean up Hetzner resources to stop billing

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

show_current_resources() {
    log_info "Current staging resources:"
    cd "${TERRAFORM_DIR}"

    if [[ ! -f "terraform.tfstate" ]]; then
        log_warn "No terraform state found. Nothing to destroy."
        exit 0
    fi

    # Show what will be destroyed
    terraform show -json | jq -r '.values.root_module.resources[]? | "\(.type): \(.values.name // .values.id)"' 2>/dev/null || \
        terraform show | grep -E "resource|name" | head -20

    echo ""
}

calculate_cost() {
    log_info "Calculating costs..."

    cd "${TERRAFORM_DIR}"

    # Get creation time from state
    if [[ -f "terraform.tfstate" ]]; then
        # Try to get server creation time
        CREATION_TIME=$(jq -r '.resources[]? | select(.type=="hcloud_server") | .instances[0].attributes.created' terraform.tfstate 2>/dev/null || echo "")

        if [[ -n "$CREATION_TIME" && "$CREATION_TIME" != "null" ]]; then
            # Calculate hours running - handle ISO 8601 format with timezone
            # Remove timezone suffix for better compatibility
            CLEAN_TIME=$(echo "$CREATION_TIME" | sed 's/\+.*//')

            # Try different date parsing methods
            if date -d "$CREATION_TIME" +%s &>/dev/null; then
                CREATED_EPOCH=$(date -d "$CREATION_TIME" +%s)
            elif date -d "$CLEAN_TIME" +%s &>/dev/null; then
                CREATED_EPOCH=$(date -d "$CLEAN_TIME" +%s)
            else
                log_warn "Could not parse creation time: $CREATION_TIME"
                CREATED_EPOCH=0
            fi

            NOW_EPOCH=$(date +%s)

            # Validate epoch is reasonable (after 2020-01-01)
            if [[ $CREATED_EPOCH -gt 1577836800 && $CREATED_EPOCH -le $NOW_EPOCH ]]; then
                HOURS_RUNNING=$(( (NOW_EPOCH - CREATED_EPOCH) / 3600 ))

                # Sanity check - if more than 30 days, something is wrong
                if [[ $HOURS_RUNNING -le 720 ]]; then
                    COST=$(echo "scale=3; $HOURS_RUNNING * 0.008" | bc)
                    echo ""
                    echo "=========================================="
                    log_info "Resource Usage"
                    echo "=========================================="
                    echo "Running time:  ${HOURS_RUNNING} hours"
                    echo "Estimated cost: €${COST}"
                    echo "=========================================="
                    echo ""
                else
                    log_warn "Calculated runtime seems incorrect (${HOURS_RUNNING} hours)"
                fi
            fi
        fi
    fi
}

destroy_infrastructure() {
    log_warn "This will DESTROY all staging infrastructure"
    log_warn "Server will be deleted and billing will stop"
    echo ""
    read -p "Are you sure? [y/N] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Destruction cancelled"
        exit 0
    fi

    cd "${TERRAFORM_DIR}"

    log_info "Destroying infrastructure..."
    terraform destroy -var-file="terraform.staging.tfvars" -auto-approve

    log_info "✓ Infrastructure destroyed"
    log_info "✓ Billing stopped"
}

cleanup_state() {
    log_info "Cleaning up local state files..."

    cd "${TERRAFORM_DIR}"

    # Remove plan files
    rm -f staging.tfplan

    log_info "✓ Cleanup complete"
}

# Main
main() {
    log_info "Hetzner Staging Destruction"
    echo "=========================================="

    show_current_resources
    calculate_cost
    destroy_infrastructure
    cleanup_state

    echo ""
    echo "=========================================="
    log_info "All done!"
    echo "=========================================="
    echo "No more Hetzner resources running"
    echo "No more billing"
    echo ""
    echo "To deploy again: ./scripts/staging-deploy.sh"
    echo "=========================================="
}

main "$@"
