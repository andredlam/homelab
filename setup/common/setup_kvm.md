# KVM/QEMU Setup Guide for Ubuntu 24.04

## Overview

This guide covers the complete setup of KVM (Kernel-based Virtual Machine) with QEMU and libvirt on Ubuntu 24.04 LTS. KVM provides near-native performance virtualization on Linux systems and is ideal for homelab environments.

## Prerequisites

### Hardware Requirements

- **CPU**: Intel VT-x or AMD-V virtualization support
- **RAM**: Minimum 8GB (16GB+ recommended for multiple VMs)
- **Storage**: 50GB+ free space (SSD recommended)
- **Network**: At least one network interface (two recommended for advanced setups)

### Software Requirements

- Ubuntu 24.04 LTS (Server or Desktop)
- Root or sudo access
- Internet connection for package installation

### Network Interfaces (Recommended Setup)

- **eno1** (or eth0): Management interface
- **eno2** (or eth1): Data plane interface (optional, for advanced networking)

## Pre-Installation Checks

### 1. Verify CPU Virtualization Support

```bash
# Check for virtualization extensions
egrep -c '(vmx|svm)' /proc/cpuinfo
# Should return a number > 0

# Check specific CPU flags
lscpu | grep Virtualization
# Should show: Virtualization: VT-x (Intel) or AMD-V (AMD)

# Alternative check
grep -E "(vmx|svm)" /proc/cpuinfo
```

### 2. Verify Virtualization is Enabled in BIOS

```bash
# Install CPU checker utility
sudo apt update
sudo apt install -y cpu-checker

# Check KVM readiness
kvm-ok
# Expected output:
# INFO: /dev/kvm exists
# KVM acceleration can be used
```

If KVM is not available, you need to:
1. Reboot and enter BIOS/UEFI settings
2. Enable Intel VT-x or AMD-V
3. Enable Intel VT-d or AMD IOMMU (for device passthrough)
4. Save and reboot

## KVM Installation

### 1. Update System

```bash
# Update package lists and system
sudo apt update && sudo apt upgrade -y

# Install essential build tools
sudo apt install -y build-essential
```

### 2. Install KVM and Related Packages

```bash
# Install core KVM packages
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-daemon \
    libvirt-clients \
    virtinst \
    virt-manager \
    virt-viewer \
    bridge-utils \
    qemu-utils \
    guestfs-tools \
    libosinfo-bin

# Install additional useful packages
sudo apt install -y \
    virt-top \
    libguestfs-tools \
    cloud-image-utils \
    whois \
    dnsmasq-base \
    ebtables

# Optional: Install OpenVSwitch for advanced networking
sudo apt install -y openvswitch-switch
```

### 3. Configure Libvirt Service

```bash
# Start and enable libvirt daemon
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd

# Verify service status
sudo systemctl status libvirtd

# Check libvirt version
libvirtd --version
```

### 4. Configure User Permissions

```bash
# Add current user to required groups
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER

# Verify group membership
groups $USER

# Apply group changes (logout/login or use newgrp)
newgrp kvm
newgrp libvirt

# Test virsh access
virsh list --all
```

### 5. Create Management User (Optional)

```bash
# Create dedicated user for VM management
sudo adduser ansible
sudo usermod -aG sudo ansible
sudo usermod -aG kvm ansible
sudo usermod -aG libvirt ansible

# Set password for ansible user
sudo passwd ansible

# Test access
sudo -u ansible virsh list --all
```

## Network Configuration

### 1. Default Network Setup

```bash
# Check default network status
virsh net-list --all

# If default network doesn't exist, create it
sudo virsh net-define /usr/share/libvirt/networks/default.xml
sudo virsh net-start default
sudo virsh net-autostart default

# Verify network configuration
virsh net-info default
virsh net-dumpxml default
```

### 2. Bridge Network Configuration

For VMs to have direct network access, create a bridge interface:

```bash
# Backup current netplan configuration
sudo cp /etc/netplan/*.yaml /etc/netplan/backup/

# Create bridge configuration
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      dhcp4: false
      dhcp6: false
  bridges:
    br0:
      dhcp4: true
      interfaces:
        - eno1
      parameters:
        stp: false
        forward-delay: 0
EOF

# Apply network configuration
sudo netplan apply

# Verify bridge creation
ip addr show br0
brctl show
```

### 3. Configure Bridge for Libvirt

```bash
# Create bridge network XML definition
cat > /tmp/br0.xml << 'EOF'
<network>
  <name>br0</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
EOF

# Define and start bridge network
virsh net-define /tmp/br0.xml
virsh net-start br0
virsh net-autostart br0

# List networks
virsh net-list --all
```

## Performance Optimization

### 1. Kernel Parameters

```bash
# Create performance optimization configuration
sudo tee /etc/sysctl.d/60-kvm-performance.conf > /dev/null << 'EOF'
# KVM Performance optimizations
vm.swappiness = 10
vm.vfs_cache_pressure = 50
kernel.sched_migration_cost_ns = 5000000

# Network performance
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Disable bridge netfilter for performance
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
EOF

# Apply settings
sudo sysctl -p /etc/sysctl.d/60-kvm-performance.conf
```

### 2. Bridge Netfilter Rules

```bash
# Create udev rule for automatic bridge netfilter disable
sudo tee /etc/udev/rules.d/99-bridge.rules > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/sbin/sysctl -p /etc/sysctl.d/60-kvm-performance.conf"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
```

### 3. CPU Governor Configuration

```bash
# Install CPU frequency utils
sudo apt install -y cpufrequtils

# Set performance governor for better VM performance
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils

# Apply immediately
sudo systemctl restart cpufrequtils

# Verify governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### 4. Hugepages Configuration (Optional)

```bash
# Calculate hugepages (example: 4GB for hugepages)
echo 2048 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Make hugepages persistent
echo 'vm.nr_hugepages = 2048' | sudo tee -a /etc/sysctl.conf

# Verify hugepages
cat /proc/meminfo | grep -i huge
```

## Storage Configuration

### 1. Create Storage Pools

```bash
# Create directory for VM storage
sudo mkdir -p /var/lib/libvirt/images
sudo mkdir -p /var/lib/libvirt/iso

# Set proper ownership
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/iso

# Define default storage pool
virsh pool-define-as default dir --target /var/lib/libvirt/images
virsh pool-autostart default
virsh pool-start default

# Define ISO storage pool
virsh pool-define-as iso dir --target /var/lib/libvirt/iso
virsh pool-autostart iso
virsh pool-start iso

# Verify storage pools
virsh pool-list --all
virsh pool-info default
```

### 2. Alternative Storage Pool (Optional)

```bash
# Create storage pool on different mount point (if available)
sudo mkdir -p /opt/vm-storage
sudo chown libvirt-qemu:libvirt-qemu /opt/vm-storage

# Define custom storage pool
virsh pool-define-as vm-storage dir --target /opt/vm-storage
virsh pool-autostart vm-storage
virsh pool-start vm-storage
```

## Firewall Configuration

### 1. Configure UFW for KVM

```bash
# Enable UFW if not already enabled
sudo ufw enable

# Allow libvirt management
sudo ufw allow from 192.168.122.0/24
sudo ufw allow in on virbr0
sudo ufw allow out on virbr0

# Allow bridge traffic
sudo ufw allow in on br0
sudo ufw allow out on br0

# Allow VNC connections (if using graphical console)
sudo ufw allow 5900:5999/tcp

# Check UFW status
sudo ufw status verbose
```

### 2. Configure iptables for Bridge (Alternative)

```bash
# Allow bridge traffic
sudo iptables -I FORWARD -i br0 -j ACCEPT
sudo iptables -I FORWARD -o br0 -j ACCEPT

# Save iptables rules
sudo iptables-save > /etc/iptables/rules.v4
```

## VM Management Commands

### 1. Basic VM Operations

```bash
# List all VMs
virsh list --all

# Start a VM
virsh start <vm-name>

# Stop a VM gracefully
virsh shutdown <vm-name>

# Force stop a VM
virsh destroy <vm-name>

# Suspend a VM
virsh suspend <vm-name>

# Resume a VM
virsh resume <vm-name>

# Reboot a VM
virsh reboot <vm-name>

# Auto-start VM on host boot
virsh autostart <vm-name>

# Disable auto-start
virsh autostart --disable <vm-name>
```

### 2. VM Console Access

```bash
# Connect to VM console
virsh console <vm-name>
# Exit console with: Ctrl + ]

# Connect via VNC (if VM has graphics)
virt-viewer <vm-name>

# Get VNC port information
virsh vncdisplay <vm-name>
```

### 3. VM Information and Monitoring

```bash
# Get VM information
virsh dominfo <vm-name>

# Get VM state
virsh domstate <vm-name>

# Monitor VM performance
virsh domstats <vm-name>

# List VM block devices
virsh domblklist <vm-name>

# List VM network interfaces
virsh domiflist <vm-name>

# Real-time VM monitoring
virt-top
```

### 4. VM Lifecycle Management

```bash
# Clone a VM
virt-clone --original <source-vm> --name <new-vm> --auto-clone

# Delete a VM completely
virsh undefine <vm-name> --remove-all-storage

# Export VM configuration
virsh dumpxml <vm-name> > <vm-name>.xml

# Import VM configuration
virsh define <vm-name>.xml

# Edit VM configuration
virsh edit <vm-name>
```

### 5. Snapshot Management

```bash
# Create snapshot
virsh snapshot-create-as <vm-name> <snapshot-name> "Description"

# List snapshots
virsh snapshot-list <vm-name>

# Restore snapshot
virsh snapshot-revert <vm-name> <snapshot-name>

# Delete snapshot
virsh snapshot-delete <vm-name> <snapshot-name>

# Get snapshot info
virsh snapshot-info <vm-name> <snapshot-name>
```

## Creating Your First VM

### 1. Download Ubuntu ISO

```bash
# Download Ubuntu 24.04 Server ISO
cd /var/lib/libvirt/iso
sudo wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

# Verify download
ls -lh ubuntu-24.04-live-server-amd64.iso
```

### 2. Create VM Using virt-install

```bash
# Create a new VM
sudo virt-install \
  --name ubuntu-test \
  --ram 2048 \
  --disk path=/var/lib/libvirt/images/ubuntu-test.qcow2,size=20,format=qcow2 \
  --vcpus 2 \
  --os-type linux \
  --os-variant ubuntu24.04 \
  --network bridge=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --location /var/lib/libvirt/iso/ubuntu-24.04-live-server-amd64.iso \
  --extra-args 'console=ttyS0,115200n8 serial'

# Alternative with VNC graphics
sudo virt-install \
  --name ubuntu-gui \
  --ram 4096 \
  --disk path=/var/lib/libvirt/images/ubuntu-gui.qcow2,size=30,format=qcow2 \
  --vcpus 2 \
  --os-type linux \
  --os-variant ubuntu24.04 \
  --network bridge=br0 \
  --graphics vnc,listen=0.0.0.0 \
  --cdrom /var/lib/libvirt/iso/ubuntu-24.04-live-server-amd64.iso
```

### 3. Connect to VM During Installation

```bash
# For console installation
virsh console ubuntu-test

# For VNC installation (from another machine)
vncviewer <host-ip>:5900
```

## Advanced Configuration

### 1. Enable Nested Virtualization

```bash
# Check if nested virtualization is supported
cat /sys/module/kvm_intel/parameters/nested  # For Intel
cat /sys/module/kvm_amd/parameters/nested    # For AMD

# Enable nested virtualization
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm.conf
# For AMD: echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm.conf

# Reload KVM modules
sudo modprobe -r kvm_intel && sudo modprobe kvm_intel
# Or reboot for changes to take effect

# Verify nested virtualization
cat /sys/module/kvm_intel/parameters/nested
```

### 2. GPU Passthrough (Optional)

```bash
# Enable IOMMU in GRUB
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& intel_iommu=on iommu=pt/' /etc/default/grub
# For AMD: add "amd_iommu=on iommu=pt"

# Update GRUB
sudo update-grub

# Add VFIO modules
echo 'vfio' | sudo tee -a /etc/modules
echo 'vfio_iommu_type1' | sudo tee -a /etc/modules
echo 'vfio_pci' | sudo tee -a /etc/modules

# Update initramfs
sudo update-initramfs -u

# Reboot required
sudo reboot
```

### 3. SR-IOV Configuration (Advanced)

```bash
# Check if network card supports SR-IOV
lspci -v | grep -i sriov

# Enable SR-IOV for specific device (example)
echo 4 | sudo tee /sys/class/net/eno2/device/sriov_numvfs

# Make persistent (add to rc.local or systemd service)
echo 'echo 4 > /sys/class/net/eno2/device/sriov_numvfs' | sudo tee -a /etc/rc.local
```

## Troubleshooting

### 1. Common Issues and Solutions

```bash
# Issue: Permission denied accessing /dev/kvm
sudo usermod -aG kvm $USER
newgrp kvm

# Issue: Libvirt daemon not running
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Issue: Default network not available
sudo virsh net-start default
sudo virsh net-autostart default

# Issue: Bridge networking not working
sudo netplan apply
sudo systemctl restart systemd-networkd

# Issue: VM won't start
virsh dominfo <vm-name>
sudo journalctl -u libvirtd -f

# Issue: Poor VM performance
# Check CPU governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
# Enable hugepages
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

### 2. Diagnostic Commands

```bash
# Check KVM status
kvm-ok
lsmod | grep kvm

# Check libvirt status
sudo systemctl status libvirtd
virsh version

# Check network configuration
virsh net-list --all
ip addr show
brctl show

# Check storage pools
virsh pool-list --all
virsh vol-list default

# Check VM logs
sudo journalctl -u libvirtd -f
virsh dominfo <vm-name>

# Check host resources
free -h
df -h
top
```

### 3. Performance Monitoring

```bash
# Monitor VM performance
virt-top

# Check VM statistics
virsh domstats <vm-name>

# Monitor bridge traffic
sudo tcpdump -i br0

# Check CPU usage per VM
virsh cpu-stats <vm-name>

# Check memory usage
virsh memstat <vm-name>
```

## Security Considerations

### 1. Access Control

```bash
# Restrict libvirt access to specific users only
sudo gpasswd -d <username> libvirt  # Remove user from libvirt group

# Use PolicyKit for fine-grained access control
sudo tee /etc/polkit-1/localauthority/50-local.d/50-libvirt.pkla > /dev/null << 'EOF'
[libvirt Management]
Identity=unix-group:libvirt
Action=org.libvirt.unix.manage
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
```

### 2. Network Security

```bash
# Isolate VM networks
virsh net-edit default
# Add <ip> section with dhcp disabled for static networks

# Create isolated network
cat > /tmp/isolated.xml << 'EOF'
<network>
  <name>isolated</name>
  <bridge name="virbr1" stp="on" delay="0"/>
  <ip address="10.0.1.1" netmask="255.255.255.0">
    <dhcp>
      <range start="10.0.1.100" end="10.0.1.199"/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/isolated.xml
virsh net-start isolated
virsh net-autostart isolated
```

## Backup and Maintenance

### 1. VM Backup

```bash
# Create backup script
sudo tee /usr/local/bin/vm-backup.sh > /dev/null << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/vm-backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

for vm in $(virsh list --name --state-running); do
    echo "Backing up $vm..."
    virsh snapshot-create-as $vm backup-$DATE "Backup snapshot"
    cp /var/lib/libvirt/images/$vm.qcow2 $BACKUP_DIR/$vm-$DATE.qcow2
    virsh snapshot-delete $vm backup-$DATE
done
EOF

sudo chmod +x /usr/local/bin/vm-backup.sh

# Schedule weekly backups
echo "0 2 * * 0 /usr/local/bin/vm-backup.sh" | sudo crontab -
```

### 2. System Maintenance

```bash
# Update host system regularly
sudo apt update && sudo apt upgrade -y

# Clean up old snapshots
for vm in $(virsh list --name --all); do
    virsh snapshot-list $vm --name | head -n -3 | while read snapshot; do
        virsh snapshot-delete $vm $snapshot
    done
done

# Monitor disk usage
df -h /var/lib/libvirt/images/
virsh pool-list --details
```

## Integration with Homelab

This KVM setup integrates well with:

- **Vagrant**: Use libvirt provider for development VMs
- **Ansible**: Automate VM provisioning and configuration
- **OpenStack**: Can be deployed on KVM for cloud infrastructure
- **Kubernetes**: Run K8s clusters in VMs for testing
- **Container Runtime**: Run alongside Docker/Podman for hybrid workloads

## Useful Resources

- [KVM Official Documentation](https://www.linux-kvm.org/)
- [Libvirt Documentation](https://libvirt.org/docs.html)
- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [Ubuntu KVM Guide](https://ubuntu.com/server/docs/virtualization-libvirt)
- [Red Hat Virtualization Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_virtualization/)

## Quick Reference

### Essential Commands
```bash
# VM Management
virsh list --all                    # List all VMs
virsh start <vm>                    # Start VM
virsh shutdown <vm>                 # Shutdown VM
virsh console <vm>                  # Connect to console

# Network Management
virsh net-list --all               # List networks
virsh net-start <network>          # Start network
virsh net-info <network>           # Network info

# Storage Management
virsh pool-list --all              # List storage pools
virsh vol-list <pool>              # List volumes in pool
virsh vol-info <vol> <pool>        # Volume information
```

This comprehensive guide should provide everything needed to set up and manage KVM effectively in your homelab environment.