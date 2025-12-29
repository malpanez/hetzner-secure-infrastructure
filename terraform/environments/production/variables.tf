variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "server_name" {
  description = "Name of the production server"
  type        = string
  default     = "prod-server-01"
}

variable "server_type" {
  description = "Server type"
  type        = string
  default     = "cx22" # 2 vCPU, 4GB RAM
}

variable "image" {
  description = "OS image"
  type        = string
  default     = "debian-13"
}

variable "location" {
  description = "Datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "malpanez"
}

variable "ssh_public_key" {
  description = "SSH public key (Yubikey FIDO2)"
  type        = string
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "ssh_allowed_ips" {
  description = "IPs allowed to SSH (empty = all)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]

  # For production, restrict to your IP:
  # default = ["YOUR_IP/32"]
}

variable "allow_http" {
  description = "Allow HTTP traffic"
  type        = bool
  default     = false
}

variable "allow_https" {
  description = "Allow HTTPS traffic"
  type        = bool
  default     = false
}

variable "additional_ports" {
  description = "Additional ports to open"
  type = list(object({
    protocol   = string
    port       = string
    source_ips = list(string)
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     protocol   = "tcp"
  #     port       = "8080"
  #     source_ips = ["0.0.0.0/0", "::/0"]
  #   }
  # ]
}

variable "volume_size" {
  description = "Additional volume size in GB (0 = no volume)"
  type        = number
  default     = 0
}

variable "volume_format" {
  description = "Volume filesystem format"
  type        = string
  default     = "ext4"
}

variable "volume_automount" {
  description = "Auto-mount volume"
  type        = bool
  default     = true
}

variable "enable_floating_ip" {
  description = "Enable floating IP"
  type        = bool
  default     = false
}

variable "reverse_dns_enabled" {
  description = "Enable reverse DNS"
  type        = bool
  default     = false
}

variable "reverse_dns_ptr" {
  description = "Reverse DNS PTR record"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Domain for reverse DNS"
  type        = string
  default     = "homelabforge.dev"
}

variable "prevent_destroy" {
  description = "Prevent accidental destruction"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}

# Cloudflare configuration
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_cloudflare" {
  description = "Enable Cloudflare DNS and security configuration"
  type        = bool
  default     = false # Set to true to enable automatic DNS management
}
