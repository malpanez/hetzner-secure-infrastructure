# Terraform + Ansible Integration Workflow

**Professional Infrastructure as Code Pipeline**

## 🎯 Overview

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  Terraform   │  →   │   Hetzner    │  →   │   Ansible    │
│  (Provision) │      │   Cloud API  │      │  (Configure) │
└──────────────┘      └──────────────┘      └──────────────┘
      ↓                      ↓                      ↓
  Create VMs          Servers Running      Install Software
  Networks                                 Configure Services
  Firewalls                                Deploy WordPress
  SSH Keys                                 Setup Monitoring
```

---

## 📋 Workflow Phases

### Phase 1: Terraform (Infrastructure Provisioning) ⚙️

**What it does**:
- Creates Hetzner Cloud servers
- Configures networks and firewalls
- Sets up SSH keys
- Applies labels for auto-grouping

**Output**:
- Server IPs
- Server names
- Labels (environment, role, project)

### Phase 2: Ansible Dynamic Inventory (Auto-Discovery) 🔍

**What it does**:
- Queries Hetzner Cloud API
- Discovers servers created by Terraform
- Auto-groups servers by labels
- Generates inventory dynamically

**Output**:
- Inventory with all servers
- Automatic grouping (wordpress_servers, monitoring_servers, etc.)

### Phase 3: Ansible (Configuration Management) 🔧

**What it does**:
- Installs packages
- Configures services (Nginx, PHP, MariaDB)
- Deploys WordPress + LearnDash
- Sets up monitoring (Prometheus, Grafana)
- Hardens security (SSH, firewall, AppArmor)

**Output**:
- Fully configured production environment

---

## 🔧 Implementation

### 1. Terraform Configuration

#### Update `terraform/environments/production/main.tf`

```hcl
# terraform/environments/production/main.tf

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
  
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# ========================================
# SSH Key
# ========================================
resource "hcloud_ssh_key" "default" {
  name       = "admin-key-${var.environment}"
  public_key = file(var.ssh_public_key_path)
}

# ========================================
# Network (Optional - for private networking)
# ========================================
resource "hcloud_network" "main" {
  name     = "network-${var.environment}"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# ========================================
# Firewall (Security at Hetzner level)
# ========================================
resource "hcloud_firewall" "main" {
  name = "firewall-${var.environment}"
  
  # SSH (from anywhere - will be restricted by UFW)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  
  # HTTP/HTTPS (from anywhere - Cloudflare in front)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  
  # ICMP (ping)
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# ========================================
# WordPress Server
# ========================================
resource "hcloud_server" "wordpress" {
  name        = "wordpress-${var.environment}"
  server_type = var.wordpress_server_type
  image       = var.server_image
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.main.id]
  
  # Labels for Ansible dynamic inventory
  labels = {
    environment = var.environment
    role        = "wordpress"
    project     = var.project_name
    managed_by  = "terraform"
  }
  
  # Attach to private network
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.10"
  }
  
  # Cloud-init (basic setup)
  user_data = templatefile("${path.module}/cloud-init.yml", {
    hostname = "wordpress-${var.environment}"
  })
}

# ========================================
# Monitoring Server (Optional - Conditional)
# ========================================
resource "hcloud_server" "monitoring" {
  count       = var.deploy_monitoring_server ? 1 : 0
  
  name        = "monitoring-${var.environment}"
  server_type = var.monitoring_server_type
  image       = var.server_image
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.main.id]
  
  labels = {
    environment = var.environment
    role        = "monitoring"
    project     = var.project_name
    managed_by  = "terraform"
  }
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.20"
  }
  
  user_data = templatefile("${path.module}/cloud-init.yml", {
    hostname = "monitoring-${var.environment}"
  })
}

# ========================================
# OpenBao Server (Optional - Conditional)
# ========================================
resource "hcloud_server" "openbao" {
  count       = var.deploy_openbao_server ? 1 : 0
  
  name        = "openbao-${var.environment}"
  server_type = var.openbao_server_type
  image       = var.server_image
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.main.id]
  
  labels = {
    environment = var.environment
    role        = "openbao"
    project     = var.project_name
    managed_by  = "terraform"
  }
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.30"
  }
  
  user_data = templatefile("${path.module}/cloud-init.yml", {
    hostname = "openbao-${var.environment}"
  })
}

# ========================================
# Outputs (for Ansible)
# ========================================
output "wordpress_ipv4" {
  value = hcloud_server.wordpress.ipv4_address
  description = "WordPress server public IP"
}

output "wordpress_ipv4_private" {
  value = hcloud_server.wordpress.network[0].ip
  description = "WordPress server private IP"
}

output "monitoring_ipv4" {
  value = var.deploy_monitoring_server ? hcloud_server.monitoring[0].ipv4_address : ""
  description = "Monitoring server public IP"
}

output "openbao_ipv4" {
  value = var.deploy_openbao_server ? hcloud_server.openbao[0].ipv4_address : ""
  description = "OpenBao server public IP"
}

# Generate Ansible inventory file
output "ansible_inventory" {
  value = templatefile("${path.module}/ansible-inventory.tpl", {
    wordpress_ip  = hcloud_server.wordpress.ipv4_address
    monitoring_ip = var.deploy_monitoring_server ? hcloud_server.monitoring[0].ipv4_address : ""
    openbao_ip    = var.deploy_openbao_server ? hcloud_server.openbao[0].ipv4_address : ""
  })
  description = "Generated Ansible inventory"
}
```

#### Variables (`terraform/environments/production/variables.tf`)

```hcl
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for labeling"
  type        = string
  default     = "learndash-platform"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "server_image" {
  description = "Server OS image"
  type        = string
  default     = "debian-13"  # Latest Debian
}

variable "server_location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "fsn1"  # Falkenstein, Germany
}

# ========================================
# Server Types
# ========================================
variable "wordpress_server_type" {
  description = "WordPress server type"
  type        = string
  default     = "cx21"  # 2 vCPU, 4GB RAM, 40GB SSD - €9.40/month
}

variable "monitoring_server_type" {
  description = "Monitoring server type"
  type        = string
  default     = "cx21"  # 2 vCPU, 4GB RAM
}

variable "openbao_server_type" {
  description = "OpenBao server type"
  type        = string
  default     = "cx21"  # 2 vCPU, 4GB RAM
}

# ========================================
# Deployment Flags
# ========================================
variable "deploy_monitoring_server" {
  description = "Deploy dedicated monitoring server"
  type        = bool
  default     = false  # false = deploy on WordPress server
}

variable "deploy_openbao_server" {
  description = "Deploy dedicated OpenBao server"
  type        = bool
  default     = false  # false = deploy on WordPress server
}
```

#### Cloud-Init Template (`terraform/environments/production/cloud-init.yml`)

```yaml
#cloud-config
hostname: ${hostname}

# Create admin user
users:
  - name: admin
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${ssh_public_key}

# Update packages
package_update: true
package_upgrade: true

# Install basic packages
packages:
  - python3
  - python3-apt
  - curl
  - wget
  - vim
  - git

# Set timezone
timezone: Europe/Dublin

# Disable root login
runcmd:
  - sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart sshd
```

---

### 2. Update Ansible Dynamic Inventory

Update `ansible/inventory/hetzner.yml`:

```yaml
# Dynamic inventory plugin for Hetzner Cloud
plugin: hetzner.hcloud.hcloud

# API token from environment
token: "{{ lookup('env', 'HCLOUD_TOKEN') }}"

# Keyed groups by labels (from Terraform)
keyed_groups:
  - key: labels.environment
    prefix: env
  
  - key: labels.role
    prefix: ""
    separator: "_servers"
  
  - key: labels.project
    prefix: project
  
  - key: labels.managed_by
    prefix: managed_by

# Compose variables for Ansible
compose:
  ansible_host: ipv4_address
  ansible_user: admin
  ansible_ssh_private_key_file: ~/.ssh/id_ed25519
  server_type_name: server_type.name
  datacenter_name: datacenter.name
  private_ipv4: network[0].ip if network else None

# Groups
groups:
  hetzner: true
  production: labels.environment == "production"
  terraform_managed: labels.managed_by == "terraform"

# Host variables prefix
hostvar_prefix: hcloud_
```

---

### 3. Deployment Workflow

#### Complete Deployment Script

```bash
#!/bin/bash
# deploy.sh - Complete infrastructure deployment

set -e  # Exit on error

# ========================================
# Configuration
# ========================================
ENVIRONMENT="production"
TERRAFORM_DIR="terraform/environments/${ENVIRONMENT}"
ANSIBLE_DIR="ansible"

# ========================================
# Colors for output
# ========================================
RED='\033[0.31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# ========================================
# Prerequisites Check
# ========================================
info "Checking prerequisites..."

if [ -z "$HCLOUD_TOKEN" ]; then
    error "HCLOUD_TOKEN environment variable not set"
fi

command -v terraform >/dev/null 2>&1 || error "terraform not installed"
command -v ansible >/dev/null 2>&1 || error "ansible not installed"
command -v ansible-galaxy >/dev/null 2>&1 || error "ansible-galaxy not installed"

info "✅ Prerequisites OK"

# ========================================
# Phase 1: Terraform Provisioning
# ========================================
info "Phase 1: Provisioning infrastructure with Terraform..."

cd "${TERRAFORM_DIR}"

# Initialize Terraform
info "Initializing Terraform..."
terraform init

# Plan infrastructure changes
info "Planning infrastructure changes..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "Apply Terraform changes? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    warn "Deployment cancelled"
    exit 0
fi

# Apply changes
info "Applying Terraform changes..."
terraform apply tfplan

# Extract outputs
WORDPRESS_IP=$(terraform output -raw wordpress_ipv4)
MONITORING_IP=$(terraform output -raw monitoring_ipv4 || echo "")
OPENBAO_IP=$(terraform output -raw openbao_ipv4 || echo "")

info "✅ Infrastructure provisioned"
info "   WordPress IP: ${WORDPRESS_IP}"
[ -n "$MONITORING_IP" ] && info "   Monitoring IP: ${MONITORING_IP}"
[ -n "$OPENBAO_IP" ] && info "   OpenBao IP: ${OPENBAO_IP}"

cd - >/dev/null

# ========================================
# Phase 2: Wait for servers to be ready
# ========================================
info "Phase 2: Waiting for servers to boot..."

wait_for_ssh() {
    local host=$1
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no admin@${host} "echo OK" >/dev/null 2>&1; then
            info "✅ Server ${host} is ready"
            return 0
        fi
        info "   Waiting for ${host}... (${attempt}/${max_attempts})"
        sleep 10
        ((attempt++))
    done
    
    error "Server ${host} not ready after ${max_attempts} attempts"
}

wait_for_ssh "${WORDPRESS_IP}"
[ -n "$MONITORING_IP" ] && wait_for_ssh "${MONITORING_IP}"
[ -n "$OPENBAO_IP" ] && wait_for_ssh "${OPENBAO_IP}"

info "✅ All servers ready"

# ========================================
# Phase 3: Ansible Configuration
# ========================================
info "Phase 3: Configuring servers with Ansible..."

cd "${ANSIBLE_DIR}"

# Install Ansible collections
info "Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml

# Test dynamic inventory
info "Testing Hetzner dynamic inventory..."
ansible-inventory -i inventory/hetzner.yml --graph

# Run Ansible playbook
info "Running Ansible playbook..."
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --ask-vault-pass

info "✅ Configuration complete"

# ========================================
# Phase 4: Post-Deployment Validation
# ========================================
info "Phase 4: Validating deployment..."

# Check WordPress
if curl -fsSL "http://${WORDPRESS_IP}" >/dev/null 2>&1; then
    info "✅ WordPress server responding"
else
    warn "⚠️  WordPress server not responding yet (may need a few minutes)"
fi

# Check Monitoring (if deployed)
if [ -n "$MONITORING_IP" ]; then
    if curl -fsSL "http://${MONITORING_IP}:9090" >/dev/null 2>&1; then
        info "✅ Prometheus responding"
    else
        warn "⚠️  Prometheus not responding yet"
    fi
fi

# ========================================
# Summary
# ========================================
info ""
info "========================================="
info "Deployment Complete!"
info "========================================="
info ""
info "WordPress:   http://${WORDPRESS_IP}"
[ -n "$MONITORING_IP" ] && info "Prometheus:  http://${MONITORING_IP}:9090"
[ -n "$MONITORING_IP" ] && info "Grafana:     http://${MONITORING_IP}:3000"
[ -n "$OPENBAO_IP" ] && info "OpenBao:     http://${OPENBAO_IP}:8200"
info ""
info "Next steps:"
info "1. Point your domain DNS to ${WORDPRESS_IP}"
info "2. Configure Cloudflare proxy"
info "3. Complete WordPress setup wizard"
info "4. Install LearnDash Pro license"
info ""
```

Make executable:
```bash
chmod +x deploy.sh
```

---

## 🚀 Usage

### Scenario 1: All-in-One (1 Server)

```bash
# Set environment variables
export HCLOUD_TOKEN="your-hetzner-api-token"

# Deploy
cd terraform/environments/production
terraform apply \
  -var="deploy_monitoring_server=false" \
  -var="deploy_openbao_server=false"

# Configure with Ansible
cd ../../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml
```

### Scenario 2: Separated (3 Servers)

```bash
export HCLOUD_TOKEN="your-hetzner-api-token"

terraform apply \
  -var="deploy_monitoring_server=true" \
  -var="deploy_openbao_server=true"

cd ../../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml
```

### Automated Deployment

```bash
export HCLOUD_TOKEN="your-hetzner-api-token"
./deploy.sh
```

---

## 📚 Benefits

| Benefit | Description |
|---------|-------------|
| **Infrastructure as Code** | Everything version controlled |
| **Reproducible** | Same result every time |
| **Auto-Discovery** | Ansible finds servers automatically |
| **Scalable** | Easy to add/remove servers |
| **Professional** | Industry-standard workflow |
| **No Manual Steps** | Fully automated |

---

**Last Updated**: 2025-12-26
**Status**: Production-ready
