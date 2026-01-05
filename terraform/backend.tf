# Terraform Backend Configuration
#
# CURRENT STRATEGY: Local Backend (Simple, Reliable)
# - Local state storage (terraform.tfstate)
# - No external dependencies or costs
# - Single user workflow (state locking not needed)
# - Backup via git commits
#
# SECURITY:
# - State file gitignored (never committed)
# - Contains sensitive data (IPs, resource IDs) but NOT secrets
# - Secrets in .envrc file (gitignored)
# - Regular backups recommended
#
# VARIABLES STRATEGY (CONSISTENT):
# - Secrets (HCLOUD_TOKEN, CLOUDFLARE_API_TOKEN) → .envrc file (gitignored)
# - Config (server_size, location, etc.) → terraform.prod.tfvars (version controlled)

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = ">= 1.9"
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
# Decision: Use local backend for reliability

# ========================================
# ALTERNATIVE: Cloudflare R2 Backend (Recommended for Remote State)
# ========================================
#
# Cloudflare R2 provides S3-compatible storage with FREE tier:
# - Storage: 10 GB free/month (tfstate ~50KB = FREE forever)
# - Operations: 1M writes + 10M reads free/month
# - Egress: UNLIMITED FREE (R2's killer feature vs AWS S3)
# - Cost: $0.00/month for this use case
#
# IMPORTANT: R2 does NOT support state locking (no DynamoDB equivalent)
# - Not a problem for single developer workflow
# - Use with caution in team environments
#
# Setup Steps:
# 1. Create R2 bucket in Cloudflare dashboard:
#    - Name: terraform-state-hetzner
#    - Region: Automatic
#
# 2. Create R2 API token:
#    - Permissions: Object Read & Write
#    - Scope: Apply to specific bucket (terraform-state-hetzner)
#    - Copy Access Key ID and Secret Access Key
#
# 3. Add to .envrc:
#    export AWS_ACCESS_KEY_ID="<R2_ACCESS_KEY_ID>"
#    export AWS_SECRET_ACCESS_KEY="<R2_SECRET_ACCESS_KEY>"
#
# 4. Uncomment backend config below
#
# 5. Migrate state:
#    terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket = "terraform-state-hetzner"
#     key    = "prod/terraform.tfstate"
#
#     # R2 endpoint (replace <ACCOUNT_ID> with your Cloudflare Account ID)
#     endpoints = {
#       s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
#     }
#
#     region                      = "auto"
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_region_validation      = true
#     skip_requesting_account_id  = true
#   }
# }

# ========================================
# ALTERNATIVE: OpenBao Backend (Advanced Self-Hosted)
# ========================================
#
# NOTE: Chicken-and-egg problem:
# - Need Terraform to deploy server
# - Need server to run OpenBao
# - Need OpenBao for Terraform backend
#
# SOLUTION: Deploy with local backend first, migrate to OpenBao later
#
# Migration steps (after OpenBao is deployed):
# 1. OpenBao is running on your server
# 2. Create OpenBao policy for Terraform:
#    bao policy write terraform-state - <<EOF
#    path "secret/data/terraform/*" {
#      capabilities = ["create", "read", "update", "delete", "list"]
#    }
#    path "secret/metadata/terraform/*" {
#      capabilities = ["list", "read"]
#    }
#    EOF
#
# 3. Create Terraform user in OpenBao:
#    bao auth enable userpass
#    bao write auth/userpass/users/terraform password="SECURE_PASSWORD" policies="terraform-state"
#
# 4. Uncomment backend config below
# 5. Run: terraform init -migrate-state
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
#
# Benefits:
# - Complete self-hosting (no external dependencies)
# - State locking supported (unlike R2)
# - All secrets in one place
#
# Drawbacks:
# - OpenBao must be running 24/7 for Terraform operations
# - Requires VPN or secure tunnel for remote access
