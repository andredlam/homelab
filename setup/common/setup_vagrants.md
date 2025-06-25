# Vagrant Installation Guide for Ubuntu 24.04

## Overview

Vagrant is a tool for building and managing virtual machine environments. This guide covers installation and setup on Ubuntu 24.04.

## Prerequisites

- Ubuntu 24.04 LTS
- At least 4GB RAM (8GB+ recommended)
- 20GB+ free disk space
- Virtualization enabled in BIOS

## Installation Methods

### Method 1: Official HashiCorp Repository (Recommended)

This method ensures you get the latest stable version directly from HashiCorp.

```bash
# Update package index
sudo apt update

# Install required packages
sudo apt install -y wget curl gnupg lsb-release

# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update package index
sudo apt update

# Install Vagrant
sudo apt install vagrant

# Verify installation
vagrant --version
```

### Method 2: Ubuntu Repository (Alternative)

```bash
# Update package index
sudo apt update

# Install Vagrant from Ubuntu repository
sudo apt install vagrant

# Note: This may not be the latest version
vagrant --version
```

### Method 3: Direct Download

```bash
# Download latest Vagrant (check https://www.vagrantup.com/downloads for latest version)
VAGRANT_VERSION="2.4.1"
wget https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_amd64.deb

# Install the package
sudo dpkg -i vagrant_${VAGRANT_VERSION}-1_amd64.deb

# Fix any dependency issues
sudo apt-get install -f

# Verify installation
vagrant --version

# Clean up
rm vagrant_${VAGRANT_VERSION}-1_amd64.deb
```

## Virtualization Provider Setup

Vagrant requires a virtualization provider. This guide focuses on KVM/libvirt as the recommended option for Ubuntu 24.04.

### KVM/QEMU with libvirt Setup

KVM provides better performance on Linux systems and integrates well with existing KVM infrastructure.

#### Prerequisites Check

```bash
# Check if your CPU supports virtualization
egrep -c '(vmx|svm)' /proc/cpuinfo
# Should return > 0

# Check if KVM modules are loaded
lsmod | grep kvm
# Should show kvm_intel or kvm_amd

# Verify virtualization is enabled
sudo apt install cpu-checker
kvm-ok
# Should show "KVM acceleration can be used"
```

#### Complete KVM Setup for Ubuntu 24.04

```bash
# Update system first
sudo apt update && sudo apt upgrade -y

# Install KVM and related packages
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-daemon \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    qemu-utils \
    libvirt-dev \
    build-essential \
    ruby-dev \
    libxml2-dev \
    libxslt1-dev \
    libz-dev

# Start and enable libvirt service
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd

# Add your user to required groups
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Apply group changes (or logout/login)
newgrp libvirt
newgrp kvm

# Verify libvirt is working
sudo systemctl status libvirtd
virsh list --all
```

#### Install vagrant-libvirt Plugin

```bash
# Install the libvirt plugin for Vagrant
vagrant plugin install vagrant-libvirt

# Verify plugin installation
vagrant plugin list | grep libvirt
```

#### Configure Default Libvirt Network

```bash
# Check default network
virsh net-list --all

# If default network doesn't exist, create it
virsh net-define /usr/share/libvirt/networks/default.xml
virsh net-start default
virsh net-autostart default

# Verify network configuration
virsh net-info default
```

#### Create Storage Pool for Vagrant

```bash
# Create a storage pool for Vagrant VMs
sudo mkdir -p /var/lib/libvirt/images/vagrant
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/vagrant

# Define storage pool
virsh pool-define-as vagrant dir --target /var/lib/libvirt/images/vagrant
virsh pool-autostart vagrant
virsh pool-start vagrant

# Verify storage pool
virsh pool-list --all
virsh pool-info vagrant
```

#### Sample KVM Vagrantfile

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Use Ubuntu 22.04 (24.04 box will be available soon)
  config.vm.box = "generic/ubuntu2204"
  
  # Configure libvirt provider
  config.vm.provider "libvirt" do |libvirt|
    # Set memory and CPU
    libvirt.memory = 2048
    libvirt.cpus = 2
    
    # Use the vagrant storage pool
    libvirt.storage_pool_name = "vagrant"
    
    # Set disk size
    libvirt.machine_virtual_size = 20  # 20GB
    
    # Graphics and console
    libvirt.graphics_type = "spice"
    libvirt.graphics_port = -1
    libvirt.graphics_ip = "127.0.0.1"
    
    # Network configuration
    libvirt.management_network_name = "default"
    libvirt.management_network_address = "192.168.121.0/24"
    
    # Performance optimizations
    libvirt.cpu_mode = "host-passthrough"
    libvirt.nested = true
    libvirt.volume_cache = "writeback"
    libvirt.disk_bus = "virtio"
    libvirt.nic_model_type = "virtio"
  end
  
  # Network configuration
  config.vm.network "private_network", ip: "192.168.121.10"
  
  # Shared folders (using 9p for better performance)
  config.vm.synced_folder ".", "/vagrant", type: "9p", disabled: false, accessmode: "mapped"
  
  # Provisioning
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y vim curl wget htop
    echo "KVM-based Vagrant VM is ready!"
  SHELL
end
```

#### Multi-Node KVM Setup

```ruby
Vagrant.configure("2") do |config|
  # Define cluster nodes
  nodes = [
    { name: "master", ip: "192.168.121.10", memory: 2048, cpus: 2 },
    { name: "worker1", ip: "192.168.121.11", memory: 1024, cpus: 1 },
    { name: "worker2", ip: "192.168.121.12", memory: 1024, cpus: 1 }
  ]
  
  nodes.each do |node|
    config.vm.define node[:name] do |vm|
      vm.vm.box = "generic/ubuntu2204"
      vm.vm.hostname = node[:name]
      
      # Libvirt configuration
      vm.vm.provider "libvirt" do |libvirt|
        libvirt.memory = node[:memory]
        libvirt.cpus = node[:cpus]
        libvirt.storage_pool_name = "vagrant"
        libvirt.machine_virtual_size = 20
        libvirt.cpu_mode = "host-passthrough"
      end
      
      # Network
      vm.vm.network "private_network", ip: node[:ip]
      
      # Provision only on last node
      if node[:name] == "worker2"
        vm.vm.provision "ansible" do |ansible|
          ansible.limit = "all"
          ansible.playbook = "cluster-setup.yml"
        end
      end
    end
  end
end
```

#### Testing KVM Setup

```bash
# Create test directory
mkdir ~/vagrant-kvm-test
cd ~/vagrant-kvm-test

# Initialize with KVM-compatible box
vagrant init generic/ubuntu2204

# Edit Vagrantfile to use libvirt provider
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"
  
  config.vm.provider "libvirt" do |libvirt|
    libvirt.memory = 1024
    libvirt.cpus = 1
    libvirt.storage_pool_name = "vagrant"
  end
  
  config.vm.network "private_network", ip: "192.168.121.100"
end
EOF

# Start the VM
vagrant up --provider=libvirt

# SSH into the VM
vagrant ssh

# Check VM status
vagrant status

# Clean up
vagrant destroy -f
```

#### KVM-Specific Commands

```bash
# Start VM with specific provider
vagrant up --provider=libvirt

# Check libvirt VMs
virsh list --all

# Monitor VM resource usage
virsh dominfo <vm-name>
virsh domstats <vm-name>

# Access VM console directly
virsh console <vm-name>

# Take VM snapshot
virsh snapshot-create-as <vm-name> snapshot1

# List snapshots
virsh snapshot-list <vm-name>
```

#### Performance Optimization for KVM

```ruby
config.vm.provider "libvirt" do |libvirt|
  # CPU optimizations
  libvirt.cpu_mode = "host-passthrough"  # Best performance
  libvirt.cpu_fallback = "allow"
  libvirt.nested = true                  # Enable nested virtualization
  
  # Memory optimizations
  libvirt.memory = 2048
  libvirt.hugepages = 1024              # Use hugepages if available
  
  # Disk optimizations
  libvirt.disk_bus = "virtio"           # Faster disk I/O
  libvirt.volume_cache = "writeback"    # Better disk performance
  libvirt.disk_driver = "qcow2"
  
  # Network optimizations
  libvirt.nic_model_type = "virtio"     # Faster network
  
  # Additional performance settings
  libvirt.video_type = "qxl"
  libvirt.sound_type = nil              # Disable sound for servers
  libvirt.graphics_type = "none"        # Disable graphics for headless
end
```

## Essential Vagrant Plugins

Install these useful plugins to enhance your Vagrant experience with KVM:

```bash
# Plugin for KVM/libvirt support (should already be installed)
vagrant plugin install vagrant-libvirt

# Plugin for better disk management
vagrant plugin install vagrant-disksize

# Plugin for host manager (automatic /etc/hosts management)
vagrant plugin install vagrant-hostmanager

# Plugin for environment variables
vagrant plugin install vagrant-env

# List installed plugins
vagrant plugin list
```

## Basic Vagrant Configuration

### Create Your First Vagrant Environment

```bash
# Create a new directory for your Vagrant project
mkdir ~/vagrant-test
cd ~/vagrant-test

# Initialize a new Vagrantfile with Ubuntu 22.04
vagrant init ubuntu/jammy64

# Or initialize with Ubuntu 24.04 (when available)
# vagrant init ubuntu/noble64

# Start the virtual machine
vagrant up

# SSH into the VM
vagrant ssh

# Check VM status
vagrant status

# Suspend the VM
vagrant suspend

# Resume the VM
vagrant resume

# Stop and destroy the VM
vagrant halt
vagrant destroy
```

### Sample Vagrantfile for Ubuntu 24.04

Create a custom `Vagrantfile` using KVM (recommended):

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Base box
  config.vm.box = "generic/ubuntu2204"  # Use ubuntu2204 until ubuntu2404 is available
  
  # KVM/libvirt configuration (recommended)
  config.vm.provider "libvirt" do |libvirt|
    libvirt.memory = 2048
    libvirt.cpus = 2
    libvirt.storage_pool_name = "vagrant"
    libvirt.cpu_mode = "host-passthrough"
    libvirt.disk_bus = "virtio"
    libvirt.nic_model_type = "virtio"
  end
  
  # Network configuration
  config.vm.network "private_network", ip: "192.168.121.10"
  
  # Shared folders (using 9p for better performance with KVM)
  config.vm.synced_folder ".", "/vagrant", type: "9p", disabled: false, accessmode: "mapped"
  config.vm.synced_folder "./shared", "/vagrant_shared", type: "9p", create: true, accessmode: "mapped"
  
  # Provisioning script
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get upgrade -y
    
    # Install common tools
    apt-get install -y curl wget vim git htop tree
    
    # Install Docker (example)
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker vagrant
    
    # Clean up
    rm get-docker.sh
    apt-get autoremove -y
    apt-get autoclean
    
    echo "KVM-based Ubuntu VM is ready!"
  SHELL
  
  # Host manager plugin configuration
  if Vagrant.has_plugin?("vagrant-hostmanager")
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.manage_guest = true
  end
end
```



## Multi-Machine Setup

For more complex environments, you can define multiple VMs using KVM:

```ruby
Vagrant.configure("2") do |config|
  # Define multiple machines using KVM
  (1..3).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.box = "generic/ubuntu2204"
      node.vm.hostname = "node#{i}"
      node.vm.network "private_network", ip: "192.168.121.#{10+i}"
      
      # KVM/libvirt configuration
      node.vm.provider "libvirt" do |libvirt|
        libvirt.memory = 1024
        libvirt.cpus = 1
        libvirt.storage_pool_name = "vagrant"
        libvirt.cpu_mode = "host-passthrough"
      end
      
      # Only provision on the last machine
      if i == 3
        node.vm.provision "ansible" do |ansible|
          ansible.limit = "all"
          ansible.playbook = "playbooks/cluster-setup.yml"
          ansible.inventory_path = "inventory/hosts"
        end
      end
    end
  end
end
```



## Common Vagrant Commands

```bash
# Initialize new Vagrant environment
vagrant init [box-name]

# Start VM(s)
vagrant up [vm-name]

# SSH into VM
vagrant ssh [vm-name]

# Check status
vagrant status

# Suspend/resume VM
vagrant suspend [vm-name]
vagrant resume [vm-name]

# Restart VM
vagrant reload [vm-name]

# Halt VM
vagrant halt [vm-name]

# Destroy VM
vagrant destroy [vm-name]

# Re-run provisioning
vagrant provision [vm-name]

# Show SSH configuration
vagrant ssh-config

# Package current VM as box
vagrant package

# List available boxes
vagrant box list

# Add a new box
vagrant box add <name> <url>

# Remove a box
vagrant box remove <name>

# Update boxes
vagrant box update
```

## Troubleshooting

### Common Issues and Solutions

#### 1. VT-x/AMD-V Not Available
```bash
# Check if virtualization is enabled
grep -E "(vmx|svm)" /proc/cpuinfo

# If empty, enable virtualization in BIOS
# Look for Intel VT-x or AMD-V settings
```



#### 5. Plugin Installation Issues
```bash
# Install development tools if plugin compilation fails
sudo apt install build-essential ruby-dev

# Clear plugin cache
rm -rf ~/.vagrant.d/gems/
vagrant plugin install <plugin-name>
```

### Log Files and Debugging

```bash
# Enable debug logging
VAGRANT_LOG=debug vagrant up

# Check Vagrant logs
tail -f ~/.vagrant.d/logs/vagrant.log
```

## Performance Optimization

### Host System Optimizations

```bash
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize kernel parameters for virtualization
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
```

## Integration with Your Homelab

### Using Vagrant for OVN/OVS Testing

Create a Vagrantfile for your OVN learning environment using KVM:

```ruby
Vagrant.configure("2") do |config|
  # OVN Central node
  config.vm.define "ovn-central" do |central|
    central.vm.box = "generic/ubuntu2204"
    central.vm.hostname = "ovn-central"
    central.vm.network "private_network", ip: "192.168.121.10"
    
    # KVM/libvirt configuration
    central.vm.provider "libvirt" do |libvirt|
      libvirt.memory = 2048
      libvirt.cpus = 2
      libvirt.storage_pool_name = "vagrant"
      libvirt.cpu_mode = "host-passthrough"
      libvirt.nested = true  # Enable nested virtualization for OVS
    end
    
    central.vm.provision "shell", path: "scripts/install-ovn-central.sh"
  end
  
  # OVN compute nodes
  (1..2).each do |i|
    config.vm.define "ovn-compute#{i}" do |compute|
      compute.vm.box = "generic/ubuntu2204"
      compute.vm.hostname = "ovn-compute#{i}"
      compute.vm.network "private_network", ip: "192.168.121.#{10+i}"
      
      # KVM/libvirt configuration
      compute.vm.provider "libvirt" do |libvirt|
        libvirt.memory = 1024
        libvirt.cpus = 1
        libvirt.storage_pool_name = "vagrant"
        libvirt.cpu_mode = "host-passthrough"
        libvirt.nested = true  # Enable nested virtualization for OVS
      end
      
      compute.vm.provision "shell", path: "scripts/install-ovn-compute.sh"
    end
  end
end
```

### Integration with Existing KVM Infrastructure

Since you already have KVM infrastructure, Vagrant can leverage your existing setup:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider "libvirt" do |libvirt|
    # Use your existing storage pool
    libvirt.storage_pool_name = "default"  # or your existing pool name
    
    # Connect to existing libvirt network
    libvirt.management_network_name = "default"
    
    # Bridge to existing host networks
    libvirt.management_network_address = "192.168.122.0/24"
  end
  
  # Bridge to existing host network
  config.vm.network "public_network", 
    dev: "br0",                    # Your existing bridge from KVM setup
    mode: "bridge",
    type: "bridge"
end
```

## Next Steps

1. **Test Your Installation**: Create a simple Vagrant environment
2. **Explore Boxes**: Browse available boxes at https://app.vagrantup.com/boxes/search
3. **Learn Provisioning**: Try shell, Ansible, or Puppet provisioning
4. **Build Custom Boxes**: Create your own base boxes for reuse
5. **Integrate with Your Homelab**: Use Vagrant for testing before deploying to production

## Useful Resources

- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Vagrant Box Catalog](https://app.vagrantup.com/boxes/search)
- [Vagrant Community](https://discuss.hashicorp.com/c/vagrant/)
- [KVM/libvirt Documentation](https://libvirt.org/)

## Quick Start Scripts

### KVM Setup Script (Recommended)

Save this as `vagrant-kvm-setup.sh`:

```bash
#!/bin/bash

# Vagrant + KVM setup script for Ubuntu 24.04

set -e

echo "Setting up Vagrant with KVM on Ubuntu 24.04..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root" 
   exit 1
fi

# Check CPU virtualization support
echo "Checking CPU virtualization support..."
if ! egrep -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
    echo "ERROR: CPU does not support virtualization"
    exit 1
fi

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install prerequisites
echo "Installing prerequisites..."
sudo apt install -y wget curl gnupg lsb-release cpu-checker

# Add HashiCorp repository
echo "Adding HashiCorp repository..."
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Vagrant
echo "Installing Vagrant..."
sudo apt update
sudo apt install -y vagrant

# Install KVM and dependencies
echo "Installing KVM and libvirt..."
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-daemon \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    qemu-utils \
    libvirt-dev \
    build-essential \
    ruby-dev \
    libxml2-dev \
    libxslt1-dev \
    libz-dev

# Start and enable libvirt
echo "Starting libvirt services..."
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd

# Add user to groups
echo "Adding user to required groups..."
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Check KVM readiness
echo "Checking KVM readiness..."
kvm-ok

# Setup default network
echo "Setting up default libvirt network..."
if ! virsh net-list --all | grep -q default; then
    sudo virsh net-define /usr/share/libvirt/networks/default.xml
fi
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default

# Create Vagrant storage pool
echo "Creating Vagrant storage pool..."
sudo mkdir -p /var/lib/libvirt/images/vagrant
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/vagrant

if ! virsh pool-list --all | grep -q vagrant; then
    virsh pool-define-as vagrant dir --target /var/lib/libvirt/images/vagrant
fi
virsh pool-autostart vagrant 2>/dev/null || true
virsh pool-start vagrant 2>/dev/null || true

# Install vagrant-libvirt plugin
echo "Installing vagrant-libvirt plugin..."
vagrant plugin install vagrant-libvirt

# Install additional useful plugins
echo "Installing additional Vagrant plugins..."
vagrant plugin install vagrant-hostmanager

# Create test Vagrantfile
echo "Creating test Vagrantfile..."
mkdir -p ~/vagrant-kvm-test
cat > ~/vagrant-kvm-test/Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"
  
  config.vm.provider "libvirt" do |libvirt|
    libvirt.memory = 1024
    libvirt.cpus = 1
    libvirt.storage_pool_name = "vagrant"
    libvirt.cpu_mode = "host-passthrough"
  end
  
  config.vm.network "private_network", ip: "192.168.121.100"
  
  config.vm.provision "shell", inline: <<-SHELL
    echo "Vagrant + KVM test VM is ready!"
    echo "VM IP: $(hostname -I)"
    echo "Test completed successfully!"
  SHELL
end
EOF

echo ""
echo "✅ Vagrant + KVM setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Log out and log back in (or run 'newgrp libvirt')"
echo "2. Test with: cd ~/vagrant-kvm-test && vagrant up --provider=libvirt"
echo "3. SSH into test VM: vagrant ssh"
echo "4. Clean up test: vagrant destroy -f"
echo ""
echo "🔧 Useful commands:"
echo "- Check status: vagrant status"
echo "- List VMs: virsh list --all"
echo "- Check storage: virsh pool-list --all"
echo "- Check networks: virsh net-list --all"
echo ""
echo "📚 Check your test directory: ~/vagrant-kvm-test"
```

### Usage

```bash
# For KVM setup (recommended)
chmod +x vagrant-kvm-setup.sh
./vagrant-kvm-setup.sh
```

## Storage Configuration for Vagrant

### Default Storage Location

By default, Vagrant stores its data in `~/.vagrant.d/`. This includes:
- Downloaded boxes (`~/.vagrant.d/boxes/`)
- Plugins (`~/.vagrant.d/gems/`)
- Global configuration (`~/.vagrant.d/Vagrantfile`)

### Changing Default Storage Location

#### Method 1: Environment Variable (Recommended)

```bash
# Set VAGRANT_HOME environment variable
export VAGRANT_HOME="/path/to/new/vagrant/home"

# Make it permanent by adding to your shell profile
echo 'export VAGRANT_HOME="/home/$USER/vagrant-storage"' >> ~/.bashrc
source ~/.bashrc

# Or for zsh users
echo 'export VAGRANT_HOME="/home/$USER/vagrant-storage"' >> ~/.zshrc
source ~/.zshrc

# Create the directory
mkdir -p $VAGRANT_HOME

# Verify the change
vagrant box list  # This will use the new location
```

#### Method 2: Move Existing Data

```bash
# Stop all running Vagrant VMs first
vagrant global-status
vagrant halt <vm-id>  # for each running VM

# Create new storage location
sudo mkdir -p /opt/vagrant-storage
sudo chown $USER:$USER /opt/vagrant-storage

# Move existing data
mv ~/.vagrant.d/* /opt/vagrant-storage/

# Set environment variable
export VAGRANT_HOME="/opt/vagrant-storage"
echo 'export VAGRANT_HOME="/opt/vagrant-storage"' >> ~/.bashrc
```

### Storage Management Best Practices

#### Monitor Disk Usage

```bash
# Check Vagrant storage usage
du -sh $VAGRANT_HOME
du -sh $VAGRANT_HOME/boxes/

# Check KVM/libvirt VM storage
sudo du -sh /var/lib/libvirt/images/

# List all boxes and their sizes
vagrant box list
vagrant box prune  # Remove old box versions
```

#### Clean Up Storage

```bash
# Remove unused boxes
vagrant box list
vagrant box remove <box-name> --box-version <version>

# Remove all old box versions (keep only latest)
vagrant box prune

# Clean up KVM/libvirt VMs
virsh list --all
virsh undefine <vm-name> --remove-all-storage

# Find and remove orphaned VM files
sudo find /var/lib/libvirt/images -name "*.qcow2" -exec ls -lh {} \;
```

#### Optimize Storage for Large Environments

```bash
# Use COW (copy-on-write) backing stores with KVM
config.vm.provider "libvirt" do |libvirt|
  libvirt.disk_driver = "qcow2"  # Efficient disk format
  libvirt.volume_cache = "writeback"  # Better performance
end

# Compress qcow2 images periodically
sudo qemu-img convert -O qcow2 -c original.qcow2 compressed.qcow2
```

### KVM/QEMU Storage

```bash
# Set libvirt storage pool location
sudo virsh pool-define-as vagrant dir --target /opt/libvirt-storage
sudo virsh pool-autostart vagrant
sudo virsh pool-start vagrant

# Configure in Vagrantfile
config.vm.provider "libvirt" do |libvirt|
  libvirt.storage_pool_name = "vagrant"
  libvirt.machine_virtual_size = 50  # 50GB disk
end
```

### Advanced Storage Scenarios

#### Multiple Storage Locations

Create a script to manage multiple storage locations:

```bash
#!/bin/bash
# vagrant-storage-manager.sh

case "$1" in
  "work")
    export VAGRANT_HOME="/opt/work-vagrant"
    ;;
  "personal")
    export VAGRANT_HOME="/home/$USER/personal-vagrant"
    ;;
  "lab")
    export VAGRANT_HOME="/opt/lab-vagrant"
    ;;
  *)
    echo "Usage: source $0 {work|personal|lab}"
    return 1
    ;;
esac

echo "Vagrant storage set to: $VAGRANT_HOME"
```

Usage:
```bash
# Source the script to change storage location
source vagrant-storage-manager.sh work
vagrant box list  # Shows boxes in work storage

source vagrant-storage-manager.sh personal
vagrant box list  # Shows boxes in personal storage
```

#### Network Storage (NFS/CIFS)

```bash
# Mount network storage for Vagrant
sudo mkdir -p /mnt/vagrant-storage
sudo mount -t nfs server:/path/to/storage /mnt/vagrant-storage

# Set Vagrant to use network storage
export VAGRANT_HOME="/mnt/vagrant-storage"

# Make mount permanent in /etc/fstab
echo "server:/path/to/storage /mnt/vagrant-storage nfs defaults 0 0" | sudo tee -a /etc/fstab
```

### Storage Monitoring and Alerts

#### Disk Space Monitoring Script

```bash
#!/bin/bash
# vagrant-storage-monitor.sh

VAGRANT_HOME=${VAGRANT_HOME:-~/.vagrant.d}
THRESHOLD=80  # Alert when 80% full

# Check Vagrant storage usage
USAGE=$(df "$VAGRANT_HOME" | tail -1 | awk '{print $5}' | sed 's/%//')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
    echo "WARNING: Vagrant storage is ${USAGE}% full!"
    echo "Location: $VAGRANT_HOME"
    echo "Consider running 'vagrant box prune' to clean up old boxes"
    
    # Show largest directories
    echo "Largest directories:"
    du -sh "$VAGRANT_HOME"/* | sort -hr | head -5
fi
```

#### Automated Cleanup Cron Job

```bash
# Add to crontab (run weekly cleanup)
crontab -e

# Add this line for weekly cleanup on Sundays at 2 AM
0 2 * * 0 /usr/bin/vagrant box prune --force
```

### Troubleshooting Storage Issues

#### Common Storage Problems

```bash
# Issue: "No space left on device"
# Check disk usage
df -h
du -sh $VAGRANT_HOME

# Clean up old boxes
vagrant box prune

# Issue: Permission denied on storage location
# Fix ownership
sudo chown -R $USER:$USER $VAGRANT_HOME

# Issue: Slow VM performance due to storage
# Move to SSD storage location
# Enable KVM optimizations in Vagrantfile

# Issue: Cannot find VMs after changing storage location
# Check VAGRANT_HOME is set correctly
echo $VAGRANT_HOME
vagrant global-status --prune  # Clean up invalid entries
```

#### Storage Performance Optimization

```bash
# For SSD storage with KVM, use optimized settings
config.vm.provider "libvirt" do |libvirt|
  libvirt.disk_bus = "virtio"
  libvirt.volume_cache = "writeback"
  libvirt.disk_driver = "qcow2"
end

# Enable I/O optimizations for KVM
config.vm.provider "libvirt" do |libvirt|
  libvirt.cpu_mode = "host-passthrough"
  libvirt.nested = true
end
```

### KVM/Libvirt Troubleshooting

#### Common KVM Issues and Solutions

```bash
# Issue 1: vagrant-libvirt plugin fails to install
# Solution: Install development dependencies
sudo apt install -y build-essential ruby-dev libxml2-dev libxslt1-dev libz-dev

# Issue 2: Permission denied when accessing libvirt
# Solution: Check user groups and restart session
groups $USER | grep -E "(libvirt|kvm)"
sudo usermod -aG libvirt,kvm $USER
# Then logout and login again

# Issue 3: Default network not available
# Solution: Create and start default network
sudo virsh net-define /usr/share/libvirt/networks/default.xml
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default

# Issue 4: Storage pool errors
# Solution: Create proper storage pool
sudo mkdir -p /var/lib/libvirt/images/vagrant
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/vagrant
virsh pool-define-as vagrant dir --target /var/lib/libvirt/images/vagrant
virsh pool-start vagrant 2>/dev/null || true
virsh pool-autostart vagrant 2>/dev/null || true

# Issue 5: Cannot connect to libvirt daemon
# Solution: Check service status and restart
sudo systemctl status libvirtd
sudo systemctl restart libvirtd
sudo systemctl enable libvirtd

# Issue 6: Nested virtualization not working
# Solution: Enable nested virtualization in kernel modules
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm.conf
# For AMD: echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm.conf
sudo modprobe -r kvm_intel && sudo modprobe kvm_intel
# Or reboot for changes to take effect

# Issue 7: Box download fails
# Solution: Check firewall and try different box
vagrant box add generic/ubuntu2204 --provider libvirt --force

# Issue 8: Slow VM performance
# Solution: Enable host CPU passthrough and virtio drivers
# (See performance optimization section above)

# Issue 9: Bridge network issues
# Solution: Check bridge configuration
brctl show
ip link show type bridge

# Issue 10: AppArmor blocking libvirt
# Solution: Check AppArmor status and adjust if needed
sudo aa-status | grep libvirt
# If needed, put libvirt in complain mode:
sudo aa-complain /usr/sbin/libvirtd
```

#### KVM Debugging Commands

```bash
# Check KVM support
kvm-ok
lscpu | grep Virtualization

# Check libvirt logs
sudo journalctl -u libvirtd -f

# Check qemu logs
sudo tail -f /var/log/libvirt/qemu/*.log

# Verify VM configuration
virsh dumpxml <vm-name>

# Check VM status
virsh dominfo <vm-name>
virsh domstate <vm-name>

# Monitor VM performance
virsh domstats <vm-name>

# Check network configuration
virsh net-list --all
virsh net-dumpxml default

# Check storage pools
virsh pool-list --all
virsh pool-info vagrant

# List all VMs managed by libvirt
virsh list --all
```

#### Integration with Existing KVM Infrastructure

If you already have KVM set up (from your `convert_ubuntu_to_kvm.md`), Vagrant will integrate seamlessly:

```bash
# Use existing storage pools
virsh pool-list --all
# Configure Vagrant to use existing pool in Vagrantfile:
# libvirt.storage_pool_name = "your-existing-pool"

# Use existing networks
virsh net-list --all
# Configure in Vagrantfile:
# libvirt.management_network_name = "your-existing-network"

# Share host bridges with Vagrant VMs
config.vm.network "public_network", 
  dev: "br0",                    # Your existing bridge
  mode: "bridge",
  type: "bridge"
```