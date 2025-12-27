variable "server_name" {
  description = "Name of the server"
  type        = string
}

variable "server_type" {
  description = "Type of server (CX11, CPX11, etc.)"
  type        = string
  default     = "cx11"
}

variable "image" {
  description = "OS image to use"
  type        = string
  default     = "debian-13"
}

variable "location" {
  description = "Location/datacenter (nbg1, fsn1, hel1, ash, hil)"
  type        = string
  default     = "nbg1"
}

variable "ssh_public_key" {
  description = "SSH public key for authentication"
  type        = string
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH port to allow in firewall"
  type        = number
  default     = 22
}

variable "ssh_allowed_ips" {
  description = "List of IPs allowed to connect via SSH"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "admin_username" {
  description = "Admin username to create"
  type        = string
  default     = "miguel"
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  default     = "production"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "firewall_ids" {
  description = "List of firewall IDs to attach to server"
  type        = list(number)
  default     = []
}

variable "create_firewall" {
  description = "Whether to create a firewall for this server"
  type        = bool
  default     = true
}

variable "allow_http" {
  description = "Allow HTTP (port 80) in firewall"
  type        = bool
  default     = false
}

variable "allow_https" {
  description = "Allow HTTPS (port 443) in firewall"
  type        = bool
  default     = false
}

variable "additional_ports" {
  description = "Additional ports to open in firewall"
  type = list(object({
    protocol   = string
    port       = string
    source_ips = list(string)
  }))
  default = []
}

variable "volume_size" {
  description = "Size of volume to create in GB (0 = no volume)"
  type        = number
  default     = 0
}

variable "volume_format" {
  description = "Filesystem format for volume (ext4, xfs)"
  type        = string
  default     = "ext4"
}

variable "volume_automount" {
  description = "Automatically mount volume"
  type        = bool
  default     = true
}

variable "enable_floating_ip" {
  description = "Create and assign a floating IP"
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
  description = "Domain for reverse DNS (used if reverse_dns_ptr is empty)"
  type        = string
  default     = "example.com"
}

variable "prevent_destroy" {
  description = "Prevent accidental destruction of resources"
  type        = bool
  default     = true
}

variable "firewall_name" {
  description = "Custom name for the firewall (defaults to server_name-firewall)"
  type        = string
  default     = ""
}

variable "volume_name" {
  description = "Custom name for the volume (defaults to server_name-volume)"
  type        = string
  default     = ""
}

variable "image_id" {
  description = "Specific image ID to use (overrides image name)"
  type        = number
  default     = null
}
