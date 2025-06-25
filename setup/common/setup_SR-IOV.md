# SR-IOV Configuration Guide for AMD + Mellanox ConnectX-3

## Overview

SR-IOV (Single Root I/O Virtualization) allows a single physical PCIe device to present itself as multiple virtual devices to virtual machines, providing near-native performance for network-intensive workloads. This guide covers SR-IOV setup on Ubuntu 24.04 with AMD processors and Mellanox ConnectX-3 NICs.

## Prerequisites

### Hardware Requirements

- **CPU**: AMD processor with IOMMU support (AMD-Vi)
- **Network Card**: Mellanox ConnectX-3 or newer with SR-IOV support
- **Motherboard**: PCIe slots with adequate bandwidth
- **Memory**: Sufficient RAM for host and VMs (16GB+ recommended)

### Software Requirements

- Ubuntu Server 24.04 LTS
- Root access
- Internet connectivity for package downloads

### BIOS/UEFI Configuration

Before proceeding, ensure these settings are enabled in your BIOS/UEFI:

1. **Virtualization Technology**: Enabled
2. **AMD-Vi (IOMMU)**: Enabled
3. **SR-IOV**: Enabled
4. **Above 4G Decoding**: Enabled (if available)
5. **MMIO High Size**: Set to 256GB or higher (if available)

## System Verification

### 1. Check Hardware Support

```bash
# Verify CPU IOMMU support
grep -q "AMD-Vi\|Intel VT-d" /proc/cpuinfo && echo "IOMMU supported" || echo "IOMMU not supported"

# Check for virtualization flags
lscpu | grep Virtualization

# Verify AMD-Vi support in kernel
dmesg | grep -i "AMD-Vi"

# List all network devices
lspci | grep -i ethernet
lspci | grep -i mellanox

# Check specific Mellanox device details
lspci -vv | grep -A 20 -i mellanox
```

### 2. Check SR-IOV Capability

```bash
# Find Mellanox device bus ID
DEVICE_ID=$(lspci | grep -i mellanox | awk '{print $1}' | head -1)
echo "Mellanox device found at: $DEVICE_ID"

# Check SR-IOV capability
lspci -vv -s $DEVICE_ID | grep -i "single root"

# Check maximum VFs supported
cat /sys/bus/pci/devices/0000:$DEVICE_ID/sriov_totalvfs 2>/dev/null || echo "SR-IOV not available"
```

## Kernel Configuration

### 1. Enable IOMMU and SR-IOV in GRUB

```bash
# Backup current GRUB configuration
sudo cp /etc/default/grub /etc/default/grub.backup

# Edit GRUB configuration
sudo vim /etc/default/grub

# Add or modify the GRUB_CMDLINE_LINUX_DEFAULT line:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt pci=realloc intel_iommu=on"

# Alternative for more detailed IOMMU logging (optional):
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt pci=realloc amd_iommu_dump intel_iommu=on"

# Update GRUB and reboot
sudo update-grub
sudo reboot
```

### 2. Verify IOMMU Activation

```bash
# After reboot, verify IOMMU is active
dmesg | grep -i iommu | head -10

# Should see output like:
# AMD-Vi: IOMMU performance counters supported
# AMD-Vi: Lazy IO/TLB flushing enabled

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | wc -l
```

### 3. Load Required Kernel Modules

```bash
# Load VFIO modules for device passthrough
sudo modprobe vfio
sudo modprobe vfio_pci
sudo modprobe vfio_iommu_type1

# Make modules persistent
echo 'vfio' | sudo tee -a /etc/modules
echo 'vfio_pci' | sudo tee -a /etc/modules
echo 'vfio_iommu_type1' | sudo tee -a /etc/modules

# Update initramfs
sudo update-initramfs -u
```

## Mellanox Driver Installation

### 1. Install Mellanox OFED Drivers

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y \
    build-essential \
    linux-headers-$(uname -r) \
    python3-pip \
    wget \
    curl \
    dkms \
    libnl-3-dev \
    libnl-route-3-dev \
    pkg-config

# Download Mellanox OFED for Ubuntu 24.04
cd /tmp
wget https://www.mellanox.com/downloads/ofed/MLNX_OFED-24.10-1.1.4.0/MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz

# Extract and install
tar -xzf MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz
cd MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64

# Install OFED stack
sudo ./mlnxofedinstall --upstream-libs --dpdk --with-mft --with-kernel-mft

# Start Mellanox Software Tools
sudo mst start

# Restart networking
sudo systemctl restart networking
```

### 2. Verify Driver Installation

```bash
# Check Mellanox modules
lsmod | grep mlx

# Check device status
sudo mst status

# Get device information
sudo mlxconfig -d /dev/mst/mt4103_pciconf0 q

# Check firmware version
sudo flint -d /dev/mst/mt4103_pciconf0 q
```

### 3. Alternative: Install DOCA (Optional)

```bash
# Download NVIDIA DOCA
# Visit: https://developer.nvidia.com/doca-downloads
# Select: Ubuntu 24.04, x86_64, doca-all profile

# Example download (check for latest version)
wget https://developer.download.nvidia.com/compute/doca/2.8.0/host/ubuntu2204/doca-host_2.8.0-204000-24.07-ubuntu2204_amd64.deb

# Install DOCA
sudo dpkg -i doca-host_*.deb
sudo apt-get install -f  # Fix any dependency issues
```

## SR-IOV Configuration

### 1. Identify Network Interface

```bash
# Find Mellanox interfaces
ip link show | grep -A1 -B1 "link/ether.*mlx"

# Get interface name (example: enp1s0f0)
INTERFACE=$(ip link show | grep -B1 "link/ether.*mlx" | grep "^[0-9]" | awk '{print $2}' | sed 's/:$//' | head -1)
echo "Primary interface: $INTERFACE"

# Get PCI device path
DEVICE_PATH=$(readlink -f /sys/class/net/$INTERFACE/device)
echo "Device path: $DEVICE_PATH"
```

### 2. Enable SR-IOV Virtual Functions

```bash
# Check current VF count
cat /sys/class/net/$INTERFACE/device/sriov_numvfs

# Check maximum VFs supported
MAX_VFS=$(cat /sys/class/net/$INTERFACE/device/sriov_totalvfs)
echo "Maximum VFs supported: $MAX_VFS"

# Enable VFs (start with 4, adjust as needed)
NUM_VFS=4
echo $NUM_VFS | sudo tee /sys/class/net/$INTERFACE/device/sriov_numvfs

# Verify VFs are created
lspci | grep -i "virtual function"
ip link show | grep -i "vf"
```

### 3. Configure Virtual Functions

```bash
# List created VFs
for vf in $(seq 0 $((NUM_VFS-1))); do
    echo "VF $vf:"
    ip link show $INTERFACE | grep "vf $vf"
done

# Configure VF 0 example
sudo ip link set $INTERFACE vf 0 mac 02:00:00:00:00:01
sudo ip link set $INTERFACE vf 0 vlan 100
sudo ip link set $INTERFACE vf 0 spoofchk on
sudo ip link set $INTERFACE vf 0 trust on
sudo ip link set $INTERFACE vf 0 state auto

# Configure additional VFs
for vf in $(seq 1 $((NUM_VFS-1))); do
    mac_suffix=$(printf "%02d" $((vf + 1)))
    sudo ip link set $INTERFACE vf $vf mac 02:00:00:00:00:$mac_suffix
    sudo ip link set $INTERFACE vf $vf vlan $((100 + vf))
    sudo ip link set $INTERFACE vf $vf spoofchk on
    sudo ip link set $INTERFACE vf $vf trust on
    sudo ip link set $INTERFACE vf $vf state auto
done
```

### 4. Make SR-IOV Configuration Persistent

```bash
# Create systemd service for SR-IOV
sudo tee /etc/systemd/system/sriov-setup.service > /dev/null << EOF
[Unit]
Description=Configure SR-IOV Virtual Functions
After=network.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/setup-sriov.sh
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

# Create SR-IOV setup script
sudo tee /usr/local/bin/setup-sriov.sh > /dev/null << EOF
#!/bin/bash
INTERFACE="$INTERFACE"
NUM_VFS=$NUM_VFS

# Enable VFs
echo \$NUM_VFS > /sys/class/net/\$INTERFACE/device/sriov_numvfs

# Wait for VFs to be created
sleep 2

# Configure VFs
for vf in \$(seq 0 \$((NUM_VFS-1))); do
    mac_suffix=\$(printf "%02d" \$((vf + 1)))
    ip link set \$INTERFACE vf \$vf mac 02:00:00:00:00:\$mac_suffix
    ip link set \$INTERFACE vf \$vf vlan \$((100 + vf))
    ip link set \$INTERFACE vf \$vf spoofchk on
    ip link set \$INTERFACE vf \$vf trust on
    ip link set \$INTERFACE vf \$vf state auto
done

echo "SR-IOV configured: \$NUM_VFS VFs on \$INTERFACE"
EOF

# Make script executable
sudo chmod +x /usr/local/bin/setup-sriov.sh

# Enable and start service
sudo systemctl enable sriov-setup.service
sudo systemctl start sriov-setup.service
```

## VM Configuration for SR-IOV

### 1. Prepare VF for Passthrough

```bash
# Find VF PCI addresses
VF_ADDRESSES=($(lspci | grep "Virtual Function" | awk '{print $1}'))
echo "VF addresses: ${VF_ADDRESSES[@]}"

# Get VF device IDs
for addr in "${VF_ADDRESSES[@]}"; do
    echo "VF $addr: $(lspci -s $addr)"
done

# Bind VF to VFIO driver
VF_ADDR="${VF_ADDRESSES[0]}"  # Use first VF as example
echo "0000:$VF_ADDR" | sudo tee /sys/bus/pci/devices/0000:$VF_ADDR/driver/unbind
echo "15b3 1004" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
```

### 2. Create VM with SR-IOV

```bash
# Example libvirt XML for SR-IOV VF passthrough
cat > /tmp/sriov-vm.xml << 'EOF'
<domain type='kvm'>
  <name>sriov-test-vm</name>
  <memory unit='KiB'>4194304</memory>
  <vcpu placement='static'>4</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-8.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state='off'/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'/>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/sriov-test-vm.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <!-- SR-IOV VF Passthrough -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x10' function='0x1'/>
      </source>
    </hostdev>
    <console type='pty'>
      <target type='serial'/>
    </console>
  </devices>
</domain>
EOF

# Create VM disk
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/sriov-test-vm.qcow2 20G

# Define and start VM
sudo virsh define /tmp/sriov-vm.xml
sudo virsh start sriov-test-vm
```

### 3. DPDK Configuration (Optional)

```bash
# Install DPDK
sudo apt install -y dpdk dpdk-dev

# Bind VF to DPDK driver
sudo dpdk-devbind.py --bind=vfio-pci 0000:$VF_ADDR

# Check DPDK binding
sudo dpdk-devbind.py --status
```

## Monitoring and Verification

### 1. SR-IOV Status Commands

```bash
# Check VF status
ip link show $INTERFACE

# Detailed VF information
for vf in $(seq 0 $((NUM_VFS-1))); do
    echo "=== VF $vf ==="
    ip link show $INTERFACE | grep "vf $vf"
    echo
done

# Check VF statistics
ethtool -S $INTERFACE | grep vf

# Check PCI device tree
lspci -tv | grep -A5 -B5 Mellanox
```

### 2. Performance Testing

```bash
# Install performance testing tools
sudo apt install -y iperf3 netperf

# Test VF performance (run on VM with VF)
# iperf3 -s  # On server
# iperf3 -c <server_ip> -t 30  # On client

# Check VF packet counters
cat /sys/class/net/$INTERFACE/statistics/rx_packets
cat /sys/class/net/$INTERFACE/statistics/tx_packets
```

### 3. Troubleshooting Commands

```bash
# Check dmesg for errors
dmesg | grep -i "mellanox\|sriov\|vfio\|iommu" | tail -20

# Check systemd logs
journalctl -u sriov-setup.service

# Verify IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V

# Check VF driver binding
for vf_addr in "${VF_ADDRESSES[@]}"; do
    echo "VF $vf_addr driver: $(basename $(readlink /sys/bus/pci/devices/0000:$vf_addr/driver) 2>/dev/null || echo 'unbound')"
done
```

## Performance Optimization

### 1. CPU and Memory Optimization

```bash
# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Configure hugepages
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Disable CPU C-states for better latency
sudo cpupower idle-set -D 0
```

### 2. Network Optimization

```bash
# Increase ring buffer sizes
sudo ethtool -G $INTERFACE rx 4096 tx 4096

# Enable hardware offloads
sudo ethtool -K $INTERFACE rx-checksumming on
sudo ethtool -K $INTERFACE tx-checksumming on
sudo ethtool -K $INTERFACE scatter-gather on
sudo ethtool -K $INTERFACE tcp-segmentation-offload on
sudo ethtool -K $INTERFACE generic-receive-offload on

# Tune interrupt coalescing
sudo ethtool -C $INTERFACE rx-usecs 50 tx-usecs 50
```

### 3. System Tuning

```bash
# Create performance tuning script
sudo tee /etc/sysctl.d/99-sriov-performance.conf > /dev/null << 'EOF'
# Network performance
net.core.rmem_default = 262144
net.core.rmem_max = 134217728
net.core.wmem_default = 262144
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Memory management
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF

# Apply settings
sudo sysctl -p /etc/sysctl.d/99-sriov-performance.conf
```

## Troubleshooting

### Common Issues and Solutions

#### 1. VFs Not Created

```bash
# Check if SR-IOV is supported
cat /sys/class/net/$INTERFACE/device/sriov_totalvfs

# Verify driver supports SR-IOV
lspci -vv -s $DEVICE_ID | grep -i sriov

# Check kernel messages
dmesg | grep -i sriov
```

#### 2. IOMMU Not Working

```bash
# Verify GRUB configuration
grep amd_iommu /proc/cmdline

# Check IOMMU status
dmesg | grep -i "amd-vi\|iommu"

# Verify BIOS settings are correct
```

#### 3. VF Passthrough Fails

```bash
# Check VFIO driver binding
lspci -k -s $VF_ADDR

# Verify IOMMU group isolation
find /sys/kernel/iommu_groups/ -name "*$VF_ADDR*"

# Check libvirt logs
sudo journalctl -u libvirtd -f
```

#### 4. Performance Issues

```bash
# Check for hardware errors
ethtool -S $INTERFACE | grep error

# Verify CPU placement
taskset -cp $$ # Check current CPU affinity

# Check interrupt distribution
cat /proc/interrupts | grep mlx
```

## Security Considerations

### 1. VF Isolation

```bash
# Enable spoof checking
sudo ip link set $INTERFACE vf 0 spoofchk on

# Set trust levels appropriately
sudo ip link set $INTERFACE vf 0 trust off  # For untrusted VMs

# Configure VLAN isolation
sudo ip link set $INTERFACE vf 0 vlan 100
```

### 2. Access Control

```bash
# Restrict VF access to specific users
sudo chown root:kvm /sys/class/net/$INTERFACE/device/sriov_numvfs
sudo chmod 664 /sys/class/net/$INTERFACE/device/sriov_numvfs
```

## Maintenance and Backup

### 1. Configuration Backup

```bash
# Backup SR-IOV configuration
sudo tee /opt/sriov-backup.sh > /dev/null << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/sriov-config-backup"
mkdir -p $BACKUP_DIR

# Backup network configuration
cp /etc/netplan/*.yaml $BACKUP_DIR/
cp /etc/default/grub $BACKUP_DIR/
cp /usr/local/bin/setup-sriov.sh $BACKUP_DIR/
cp /etc/systemd/system/sriov-setup.service $BACKUP_DIR/

# Backup current VF configuration
ip link show > $BACKUP_DIR/interfaces.txt
lspci > $BACKUP_DIR/pci-devices.txt
cat /sys/class/net/*/device/sriov_numvfs > $BACKUP_DIR/vf-count.txt

echo "SR-IOV configuration backed up to $BACKUP_DIR"
EOF

sudo chmod +x /opt/sriov-backup.sh
```

### 2. Monitoring Script

```bash
# Create monitoring script
sudo tee /usr/local/bin/sriov-monitor.sh > /dev/null << 'EOF'
#!/bin/bash

# Check VF status
echo "=== SR-IOV Status ==="
for iface in $(ls /sys/class/net/); do
    if [ -f /sys/class/net/$iface/device/sriov_numvfs ]; then
        vfs=$(cat /sys/class/net/$iface/device/sriov_numvfs)
        max_vfs=$(cat /sys/class/net/$iface/device/sriov_totalvfs)
        echo "$iface: $vfs/$max_vfs VFs active"
    fi
done

# Check VF errors
echo -e "\n=== VF Error Counters ==="
for iface in $(ls /sys/class/net/ | grep -E '^(eth|ens|enp)'); do
    if ethtool -S $iface 2>/dev/null | grep -q vf; then
        echo "Interface: $iface"
        ethtool -S $iface | grep -E 'vf.*error|vf.*drop' | head -5
    fi
done
EOF

sudo chmod +x /usr/local/bin/sriov-monitor.sh

# Add to cron for regular monitoring
echo "*/5 * * * * /usr/local/bin/sriov-monitor.sh >> /var/log/sriov-monitor.log 2>&1" | sudo crontab -
```

## Integration with Homelab

### KVM Integration

SR-IOV VFs can be used with:
- **libvirt/KVM**: Direct VF passthrough to VMs
- **OpenStack**: High-performance networking for instances  
- **Kubernetes**: With SR-IOV CNI plugin
- **Container runtime**: DPDK-enabled containers

### Use Cases

- **High-frequency trading**: Low-latency networking
- **NFV workloads**: Virtual network functions
- **HPC applications**: High-bandwidth computing
- **Network testing**: Performance validation

## References

- [Mellanox SR-IOV Documentation](https://docs.mellanox.com/display/MLNXOFEDv461000/SR-IOV)
- [Linux SR-IOV Configuration](https://www.kernel.org/doc/Documentation/PCI/pci-iov-howto.txt)
- [DPDK SR-IOV Guide](https://doc.dpdk.org/guides/nics/mlx4.html)
- [KVM SR-IOV Setup](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/configuring-sr-iov-network-virtual-functions_configuring-and-managing-virtualization)

This guide provides a complete SR-IOV setup for high-performance networking in your homelab environment.