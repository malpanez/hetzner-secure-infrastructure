#!/bin/bash
# Secure tfvars Files - Remove Secrets Before Committing
#
# This script removes sensitive data from tfvars files
# Secrets should be stored in Terraform Cloud, not in files!

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Securing tfvars Files${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "terraform/terraform.staging.tfvars" ]; then
    echo -e "${RED}ERROR: Run this script from the repository root${NC}"
    exit 1
fi

# Backup original file
echo -e "${YELLOW}[1/3] Creating backup...${NC}"
cp terraform/terraform.staging.tfvars terraform/terraform.staging.tfvars.backup
echo -e "${GREEN}✓ Backup created: terraform/terraform.staging.tfvars.backup${NC}"
echo ""

# Remove hcloud_token line
echo -e "${YELLOW}[2/3] Removing hcloud_token from terraform.staging.tfvars...${NC}"
sed -i '/^hcloud_token = /d' terraform/terraform.staging.tfvars

# Add comment about Terraform Cloud
sed -i '12 a\
# Hetzner Cloud API Token\
# SECURITY: Token stored in Terraform Cloud as HCLOUD_TOKEN environment variable\
# DO NOT add token here - Terraform Cloud injects it automatically\
# Get token from: https://console.hetzner.cloud/ (if you need to rotate it)\
' terraform/terraform.staging.tfvars

echo -e "${GREEN}✓ Removed hcloud_token from file${NC}"
echo -e "${GREEN}✓ Added security comment${NC}"
echo ""

# Verify file is safe
echo -e "${YELLOW}[3/3] Verifying file is safe to commit...${NC}"
if grep -q "hcloud_token = " terraform/terraform.staging.tfvars; then
    echo -e "${RED}✗ WARNING: hcloud_token still found in file!${NC}"
    echo -e "${RED}  Manual cleanup required${NC}"
    exit 1
else
    echo -e "${GREEN}✓ File is safe to commit (no tokens found)${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Security Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "What was done:"
echo "  ✓ Removed hcloud_token from terraform.staging.tfvars"
echo "  ✓ Added security comment about Terraform Cloud"
echo "  ✓ Created backup: terraform.staging.tfvars.backup"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff terraform/terraform.staging.tfvars"
echo "  2. Verify no secrets: grep -i 'token\|password\|secret' terraform/*.tfvars"
echo "  3. Commit safely: git add terraform/*.tfvars"
echo ""
echo -e "${YELLOW}Remember:${NC}"
echo "  - Secrets belong in Terraform Cloud (HCLOUD_TOKEN already set!)"
echo "  - tfvars files should only contain infrastructure config"
echo "  - Always review before committing: git diff"
echo ""
