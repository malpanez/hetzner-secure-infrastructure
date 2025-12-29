# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrant configuration for local testing
# Simulates Hetzner Cloud environment with Debian 12

Vagrant.configure("2") do |config|
  # Use Debian 12 (Bookworm) - same as production
  config.vm.box = "debian/bookworm64"
  config.vm.box_version = ">= 12.0"

  # ===========================================
  # WordPress All-in-One Server (Recommended)
  # ===========================================
  config.vm.define "wordpress-aio", primary: true do |wordpress|
    wordpress.vm.hostname = "wordpress-test.local"

    # Network configuration
    wordpress.vm.network "private_network", ip: "192.168.56.10"
    wordpress.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
    wordpress.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.1"

    # VM Resources
    wordpress.vm.provider "virtualbox" do |vb|
      vb.name = "hetzner-wordpress-test"
      vb.memory = "2048"
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end

    # Provision with Ansible
    wordpress.vm.provision "ansible" do |ansible|
      ansible.compatibility_mode = "2.0"
      ansible.playbook = "ansible/playbooks/site.yml"
      ansible.inventory_path = "ansible/inventory/vagrant.yml"
      ansible.limit = "wordpress_servers"
      ansible.verbose = "v"
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3"
      }

      # Install Galaxy dependencies first
      ansible.galaxy_role_file = "ansible/requirements.yml"
      ansible.galaxy_roles_path = "/tmp/ansible-roles"
      ansible.galaxy_command = "ansible-galaxy install --role-file=%{role_file} --roles-path=%{roles_path}"
    end
  end

  # ===========================================
  # Monitoring Server (Optional)
  # ===========================================
  config.vm.define "monitoring", autostart: false do |monitoring|
    monitoring.vm.hostname = "monitoring-test.local"

    monitoring.vm.network "private_network", ip: "192.168.56.11"
    monitoring.vm.network "forwarded_port", guest: 3000, host: 3000, host_ip: "127.0.0.1"  # Grafana
    monitoring.vm.network "forwarded_port", guest: 9090, host: 9090, host_ip: "127.0.0.1"  # Prometheus

    monitoring.vm.provider "virtualbox" do |vb|
      vb.name = "hetzner-monitoring-test"
      vb.memory = "1536"
      vb.cpus = 2
    end

    monitoring.vm.provision "ansible" do |ansible|
      ansible.compatibility_mode = "2.0"
      ansible.playbook = "ansible/playbooks/site.yml"
      ansible.inventory_path = "ansible/inventory/vagrant.yml"
      ansible.limit = "monitoring_servers"
      ansible.verbose = "v"
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3"
      }

      ansible.galaxy_role_file = "ansible/requirements.yml"
      ansible.galaxy_roles_path = "/tmp/ansible-roles"
      ansible.galaxy_command = "ansible-galaxy install --role-file=%{role_file} --roles-path=%{roles_path}"
    end
  end

  # ===========================================
  # OpenBao Server (Optional)
  # ===========================================
  config.vm.define "openbao", autostart: false do |openbao|
    openbao.vm.hostname = "openbao-test.local"

    openbao.vm.network "private_network", ip: "192.168.56.12"
    openbao.vm.network "forwarded_port", guest: 8200, host: 8200, host_ip: "127.0.0.1"

    openbao.vm.provider "virtualbox" do |vb|
      vb.name = "hetzner-openbao-test"
      vb.memory = "1024"
      vb.cpus = 1
    end

    openbao.vm.provision "ansible" do |ansible|
      ansible.compatibility_mode = "2.0"
      ansible.playbook = "ansible/playbooks/site.yml"
      ansible.inventory_path = "ansible/inventory/vagrant.yml"
      ansible.limit = "secrets_servers"
      ansible.verbose = "v"
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3"
      }

      ansible.galaxy_role_file = "ansible/requirements.yml"
      ansible.galaxy_roles_path = "/tmp/ansible-roles"
      ansible.galaxy_command = "ansible-galaxy install --role-file=%{role_file} --roles-path=%{roles_path}"
    end
  end

  # ===========================================
  # Common Provisioning Settings
  # ===========================================

  # Update package cache on first boot
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y python3 python3-apt
  SHELL

  # SSH settings
  config.ssh.insert_key = true
  config.ssh.forward_agent = true
end
