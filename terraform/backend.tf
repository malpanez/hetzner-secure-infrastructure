# Backend configuration for OpenBao
# Store Terraform state securely in OpenBao's KV store

terraform {
  backend "http" {
    address        = "${BAAN_ADDR}/v1/secret/data/terraform/hetzner/state"
    lock_address   = "${BAAN_ADDR}/v1/secret/data/terraform/hetzner/lock"
    unlock_address = "${BAAN_ADDR}/v1/secret/data/terraform/hetzner/lock"
    username       = "terraform"
    # Password via BAAN_TOKEN environment variable
  }
}

# Alternative: Local backend for testing
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }

# Alternative: Terraform Cloud
# terraform {
#   cloud {
#     organization = "your-org"
#     workspaces {
#       name = "hetzner-production"
#     }
#   }
# }
