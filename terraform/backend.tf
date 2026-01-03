# Terraform Backend Configuration
#
# CURRENT STRATEGY: Local Backend with Git LFS
# - Local state storage (terraform.tfstate)
# - Versioned with Git LFS (tracks large binary files efficiently)
# - No external dependencies or free tier limitations
# - Single user workflow (state locking not needed)
#
# SECURITY:
# - State file tracked in Git LFS (encrypted at rest in GitHub)
# - Contains sensitive data (IPs, resource IDs) but NOT secrets (tokens in .envrc)
# - .envrc file is gitignored (secrets never committed)
#
# VARIABLES STRATEGY (CONSISTENT):
# - Secrets (HCLOUD_TOKEN, CLOUDFLARE_API_TOKEN) → .envrc file (gitignored)
# - Config (server_size, location, etc.) → terraform.prod.tfvars (version controlled)

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = ">= 1.14"
}

# ========================================
# WHY NOT TERRAFORM CLOUD?
# ========================================
#
# Terraform Cloud free tier has critical bugs:
# 1. Remote execution mode: "Insufficient rights" error (requires paid team features)
# 2. Local execution mode: "resource not found" state lock error (bug)
# 3. Both modes fail to save state reliably in free tier
#
# Decision: Use local backend with Git LFS for reliability

# ========================================
# ALTERNATIVE: OpenBao Backend (Advanced)
# ========================================
#
# NOTE: OpenBao backend creates a chicken-and-egg problem:
# - Need Terraform to deploy server
# - Need server to run OpenBao
# - Need OpenBao for Terraform backend
#
# SOLUTION: Use Terraform Cloud first, then migrate to OpenBao later if desired
#
# To use OpenBao backend (after OpenBao is deployed):
# 1. Deploy infrastructure with Terraform Cloud first
# 2. OpenBao is now running on your server
# 3. Uncomment the backend config below
# 4. Run: terraform init -migrate-state
# 5. Terraform state moves from Cloud to OpenBao
#
# terraform {
#   backend "http" {
#     address        = "https://your-server-ip:8200/v1/secret/data/terraform/state"
#     lock_address   = "https://your-server-ip:8200/v1/secret/data/terraform/lock"
#     unlock_address = "https://your-server-ip:8200/v1/secret/data/terraform/lock"
#     username       = "terraform"
#     # Password/token set via TF_HTTP_PASSWORD environment variable
#     # export TF_HTTP_PASSWORD="your-openbao-token"
#   }
# }

# ========================================
# ALTERNATIVE: Local Backend (NOT RECOMMENDED)
# ========================================
#
# Local backend stores state in a file on your machine
# RISKS:
# - State file contains sensitive data (IP addresses, IDs)
# - Easy to accidentally commit to Git
# - No collaboration support
# - No state locking
#
# Only use for testing/development, never production
#
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }

# ========================================
# Migration Path (if needed later)
# ========================================
#
# To migrate from Terraform Cloud to OpenBao:
# 1. Ensure OpenBao is running and accessible
# 2. Create OpenBao policy for Terraform:
#    bao policy write terraform-state - <<EOF
#    path "secret/data/terraform/*" {
#      capabilities = ["create", "read", "update", "delete", "list"]
#    }
#    path "secret/metadata/terraform/*" {
#      capabilities = ["list", "read"]
#    }
#    EOF
# 3. Create Terraform user in OpenBao:
#    bao auth enable userpass
#    bao write auth/userpass/users/terraform password="SECURE_PASSWORD" policies="terraform-state"
# 4. Comment out Terraform Cloud config above
# 5. Uncomment OpenBao backend config
# 6. Run: terraform init -migrate-state
# 7. Answer "yes" to migrate state
#
# Benefits of OpenBao backend:
# - Complete self-hosting (no external dependencies)
# - All secrets in one place
# - Full control over data
#
# Drawbacks:
# - OpenBao must be running 24/7 for Terraform operations
# - More complex setup
# - Requires VPN or secure tunnel for remote access
