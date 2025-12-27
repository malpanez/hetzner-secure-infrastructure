# Variables for basic server example

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.hcloud_token) > 0
    error_message = "Hetzner Cloud token must not be empty."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string

  validation {
    condition     = length(var.ssh_public_key) > 0
    error_message = "SSH public key must not be empty."
  }

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)", var.ssh_public_key))
    error_message = "SSH public key must be in valid OpenSSH format."
  }
}
