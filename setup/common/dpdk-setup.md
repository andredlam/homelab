# DPDK Configuration Guide for Ubuntu 24.04

## Overview

DPDK (Data Plane Development Kit) is a set of libraries and drivers for fast packet processing. It bypasses the kernel networking stack to achieve high performance and low latency networking. This guide covers DPDK installation and configuration on Ubuntu 24.04.

## Prerequisites

### Hardware Requirements

- **CPU**: Intel or AMD x86_64 processor with SSE4.2 support
- **Memory**: Minimum 4GB RAM (8GB+ recommended)
- **Network Card**: DPDK-compatible NIC (Intel, Mellanox, Broadcom, etc.)
- **Hugepages**: Large memory pages support

### Software Requirements

- Ubuntu 24.04 LTS
- Root access
- Python 3.8+
- Build tools and development packages

### Supported Network Cards

Common DPDK-compatible NICs:
- **Intel**: 82599, X710, XL710, XXV710, E810 series
- **Mellanox**: ConnectX-4, ConnectX-5, ConnectX-6 series
- **Broadcom**: BCM57xxx series
- **Cavium/Marvell**: OCTEON TX series

## System Preparation

### 1. Check Hardware Compatibility

```bash
# Check CPU flags for DPDK requirements
grep -o 'sse4_2\|avx\|avx2\|avx512' /proc/cpuinfo | sort -u

# Check network cards
lspci | grep -i ethernet
lspci | grep -i network

# Get detailed NIC information
for device in $(lspci | grep -i ethernet | awk '{print $1}'); do
    echo "=== Device $device ==="
    lspci -vv -s $device | grep -E "Ethernet|Vendor|Device|Subsystem"
    echo
done
```

### 2. Install Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y \
    build-essential \
    cmake \
    ninja-build \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-pyelftools \
    libnuma-dev \
    libpcap-dev \
    pkg-config \
    meson \
    git \
    wget \
    curl

# Install additional development tools
sudo apt install -y \
    linux-headers-$(uname -r) \
    libbsd-dev \
    libelf-dev \
    zlib1g-dev \
    libssl-dev \
    libjansson-dev \
    libcrypto++-dev
```

### 3. Configure Hugepages

```bash
# Check current hugepages configuration
cat /proc/meminfo | grep -i huge

# Set hugepages for current session (2GB example)
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Make hugepages persistent
echo 'vm.nr_hugepages = 1024' | sudo tee -a /etc/sysctl.conf

# Create hugepages mount point
sudo mkdir -p /mnt/huge

# Add hugepages mount to fstab
echo 'nodev /mnt/huge hugetlbfs defaults 0 0' | sudo tee -a /etc/fstab

# Mount hugepages
sudo mount -t hugetlbfs nodev /mnt/huge

# Verify hugepages
cat /proc/meminfo | grep -i huge
```

## DPDK Installation

### Method 1: Package Installation (Recommended)

```bash
# Install DPDK packages
sudo apt install -y \
    dpdk \
    dpdk-dev \
    libdpdk-dev \
    dpdk-doc

# Install additional DPDK tools
sudo apt install -y \
    dpdk-kmods-dkms \
    librte-pmd-mlx5-22 \
    librte-pmd-mlx4-22

# Verify installation
dpdk-devbind.py --help
testpmd --help
```

### Method 2: Source Installation

```bash
# Download DPDK source
cd /tmp
DPDK_VERSION="23.11.1"
wget http://fast.dpdk.org/rel/dpdk-${DPDK_VERSION}.tar.xz
tar -xf dpdk-${DPDK_VERSION}.tar.xz
cd dpdk-${DPDK_VERSION}

# Configure build
meson setup build
cd build

# Compile DPDK
ninja

# Install DPDK
sudo ninja install
sudo ldconfig

# Add DPDK tools to PATH
echo 'export PATH=$PATH:/usr/local/bin' | sudo tee -a /etc/environment
source /etc/environment
```

### 3. Load DPDK Modules

```bash
# Load required kernel modules
sudo modprobe uio
sudo modprobe uio_pci_generic
sudo modprobe vfio-pci

# Make modules persistent
echo 'uio' | sudo tee -a /etc/modules
echo 'uio_pci_generic' | sudo tee -a /etc/modules
echo 'vfio-pci' | sudo tee -a /etc/modules

# For IOMMU support (recommended)
sudo modprobe vfio
sudo modprobe vfio_iommu_type1

echo 'vfio' | sudo tee -a /etc/modules
echo 'vfio_iommu_type1' | sudo tee -a /etc/modules
```

## DPDK Configuration

### 1. Identify Network Interfaces

```bash
# List all network devices
dpdk-devbind.py --status

# Show network devices with DPDK support
dpdk-devbind.py --status-dev net

# Get PCI device information
lspci | grep -i ethernet
```

### 2. Bind Network Interface to DPDK

```bash
# Find interface to bind (example: enp1s0f0)
INTERFACE="enp1s0f0"
PCI_ADDRESS=$(ethtool -i $INTERFACE | grep bus-info | awk '{print $2}')

echo "Interface: $INTERFACE"
echo "PCI Address: $PCI_ADDRESS"

# Bring interface down
sudo ip link set $INTERFACE down

# Bind to DPDK driver (using vfio-pci for better performance)
sudo dpdk-devbind.py --bind=vfio-pci $PCI_ADDRESS

# Alternative: use uio_pci_generic (if IOMMU not available)
# sudo dpdk-devbind.py --bind=uio_pci_generic $PCI_ADDRESS

# Verify binding
dpdk-devbind.py --status
```

### 3. Configure Environment Variables

```bash
# Create DPDK environment configuration
sudo tee /etc/environment.d/dpdk.conf > /dev/null << 'EOF'
RTE_SDK=/usr/local/share/dpdk
RTE_TARGET=x86_64-native-linuxapp-gcc
DPDK_DIR=/usr/local/share/dpdk
EOF

# For current session
export RTE_SDK=/usr/local/share/dpdk
export RTE_TARGET=x86_64-native-linuxapp-gcc
export DPDK_DIR=/usr/local/share/dpdk
```

## Testing DPDK Installation

### 1. Basic Functionality Test

```bash
# Test basic DPDK functionality
sudo testpmd -l 0-1 -n 2 -- -i

# In testpmd prompt, run:
# show port info all
# start
# show port stats all
# stop
# quit
```

### 2. Performance Testing

```bash
# Simple packet forwarding test
sudo testpmd -l 0-3 -n 2 --socket-mem 1024 -- \
    --portmask=0x3 \
    --nb-cores=2 \
    --forward-mode=macswap \
    --auto-start

# L2 forwarding test
sudo l2fwd -l 1-3 -n 2 -- -p 0x3 -q 2
```

### 3. Hugepages Verification

```bash
# Check hugepages usage
cat /proc/meminfo | grep -i huge

# Check DPDK hugepage allocation
ls -la /mnt/huge/

# Monitor hugepages usage
watch 'cat /proc/meminfo | grep -i huge'
```

## Advanced Configuration

### 1. CPU Isolation and Affinity

```bash
# Edit GRUB for CPU isolation
sudo vim /etc/default/grub

# Add CPU isolation (isolate cores 2-7 for DPDK)
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash isolcpus=2-7 nohz_full=2-7 rcu_nocbs=2-7"

# Update GRUB
sudo update-grub

# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable CPU power management
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

### 2. NUMA Configuration

```bash
# Check NUMA topology
numactl --hardware
lscpu | grep NUMA

# Allocate hugepages per NUMA node
echo 512 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
echo 512 | sudo tee /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages

# Run DPDK application with NUMA awareness
sudo testpmd -l 0-3 -n 2 --socket-mem 1024,1024 -- -i
```

### 3. Multi-Queue Configuration

```bash
# Check interface queue capabilities
ethtool -l $INTERFACE

# Set multiple queues (before binding to DPDK)
sudo ethtool -L $INTERFACE combined 4

# Configure RSS (Receive Side Scaling)
sudo ethtool -X $INTERFACE equal 4
```

## DPDK with SR-IOV

### 1. Enable SR-IOV for DPDK

```bash
# Enable VFs on DPDK-compatible interface
INTERFACE="enp1s0f0"
NUM_VFS=4

# Create VFs
echo $NUM_VFS | sudo tee /sys/class/net/$INTERFACE/device/sriov_numvfs

# Bind VF to DPDK
VF_PCI=$(dpdk-devbind.py --status | grep "Virtual Function" | head -1 | awk '{print $1}')
sudo dpdk-devbind.py --bind=vfio-pci $VF_PCI

# Verify VF binding
dpdk-devbind.py --status
```

### 2. DPDK with Mellanox ConnectX

```bash
# Install Mellanox OFED for DPDK support
wget https://www.mellanox.com/downloads/ofed/MLNX_OFED-24.10-1.1.4.0/MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz
tar -xzf MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz
cd MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64
sudo ./mlnxofedinstall --upstream-libs --dpdk

# No need to bind Mellanox cards to DPDK driver
# They work with native MLX PMD
dpdk-devbind.py --status
```

## DPDK Applications and Examples

### 1. Basic L2 Forwarding

```bash
# Create simple L2 forwarding application
cat > /tmp/l2fwd_simple.c << 'EOF'
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <rte_lcore.h>

#define RX_RING_SIZE 1024
#define TX_RING_SIZE 1024
#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 32

static int lcore_main(__rte_unused void *arg) {
    uint16_t port;
    RTE_ETH_FOREACH_DEV(port) {
        if (rte_eth_dev_socket_id(port) > 0 &&
            rte_eth_dev_socket_id(port) != (int)rte_socket_id())
            printf("WARNING: port %u is on remote NUMA node\n", port);
    }
    
    printf("Core %u forwarding packets.\n", rte_lcore_id());
    for (;;) {
        RTE_ETH_FOREACH_DEV(port) {
            struct rte_mbuf *bufs[BURST_SIZE];
            const uint16_t nb_rx = rte_eth_rx_burst(port, 0, bufs, BURST_SIZE);
            if (unlikely(nb_rx == 0))
                continue;
            const uint16_t nb_tx = rte_eth_tx_burst(port ^ 1, 0, bufs, nb_rx);
            if (unlikely(nb_tx < nb_rx)) {
                uint16_t buf;
                for (buf = nb_tx; buf < nb_rx; buf++)
                    rte_pktmbuf_free(bufs[buf]);
            }
        }
    }
}

int main(int argc, char *argv[]) {
    int ret = rte_eal_init(argc, argv);
    if (ret < 0)
        rte_panic("Cannot init EAL\n");
    
    // Initialize ports...
    // (Simplified example)
    
    rte_eal_mp_remote_launch(lcore_main, NULL, CALL_MAIN);
    rte_eal_cleanup();
    return 0;
}
EOF

# Compile (simplified - needs proper DPDK build setup)
# gcc -O3 l2fwd_simple.c -ldpdk -lrte_eal -lrte_ethdev -lrte_mbuf -o l2fwd_simple
```

### 2. Packet Generator

```bash
# Use pktgen-dpdk for traffic generation
git clone http://dpdk.org/git/apps/pktgen-dpdk
cd pktgen-dpdk
make

# Run packet generator
sudo ./app/x86_64-native-linuxapp-gcc/pktgen -l 0-3 -n 2 -- -P -m "[2:3].0"
```

### 3. Performance Monitoring

```bash
# Monitor DPDK application performance
sudo dpdk-proc-info -- --stats

# Check port statistics
sudo dpdk-telemetry.py
```

## Optimization and Tuning

### 1. CPU Optimization

```bash
# Disable CPU frequency scaling
sudo systemctl disable cpufrequtils
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable CPU idle states
sudo cpupower idle-set -D 0

# Set CPU affinity for DPDK application
taskset -c 2-7 sudo testpmd -l 2-7 -n 2 -- -i
```

### 2. Memory Optimization

```bash
# Configure 1GB hugepages (if supported)
echo 4 | sudo tee /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages

# Optimize memory allocation
echo 0 | sudo tee /proc/sys/vm/zone_reclaim_mode
echo 1 | sudo tee /proc/sys/vm/compact_memory
```

### 3. Network Optimization

```bash
# Disable interrupt coalescing
sudo ethtool -C $INTERFACE rx-usecs 0 tx-usecs 0

# Increase ring buffer sizes
sudo ethtool -G $INTERFACE rx 4096 tx 4096

# Disable offloading features for better control
sudo ethtool -K $INTERFACE rx-checksumming off
sudo ethtool -K $INTERFACE tx-checksumming off
sudo ethtool -K $INTERFACE scatter-gather off
sudo ethtool -K $INTERFACE tcp-segmentation-offload off
sudo ethtool -K $INTERFACE generic-receive-offload off
sudo ethtool -K $INTERFACE generic-segmentation-offload off
```

## Container Integration

### 1. DPDK in Docker

```bash
# Create Dockerfile for DPDK container
cat > Dockerfile << 'EOF'
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    dpdk dpdk-dev \
    hugepages \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

COPY your-dpdk-app /usr/local/bin/
CMD ["/usr/local/bin/your-dpdk-app"]
EOF

# Run DPDK container with privileges
docker run --privileged \
    --cap-add=ALL \
    -v /dev/hugepages:/dev/hugepages \
    -v /sys:/sys \
    -v /dev:/dev \
    your-dpdk-app
```

### 2. DPDK with Kubernetes

```yaml
# DPDK-enabled pod specification
apiVersion: v1
kind: Pod
metadata:
  name: dpdk-app
spec:
  containers:
  - name: dpdk-container
    image: your-dpdk-app:latest
    securityContext:
      privileged: true
    resources:
      requests:
        memory: "2Gi"
        hugepages-2Mi: "2Gi"
      limits:
        memory: "2Gi"
        hugepages-2Mi: "2Gi"
    volumeMounts:
    - name: hugepages
      mountPath: /dev/hugepages
  volumes:
  - name: hugepages
    emptyDir:
      medium: HugePages
```

## Monitoring and Debugging

### 1. DPDK Statistics

```bash
# Monitor port statistics
sudo dpdk-proc-info -- --stats

# Check memory usage
sudo dpdk-proc-info -- --memory

# Monitor queue statistics
sudo dpdk-proc-info -- --xstats
```

### 2. Performance Profiling

```bash
# Install perf tools
sudo apt install -y linux-perf

# Profile DPDK application
sudo perf record -g -F 1000 sudo testpmd -l 0-1 -n 2 -- -i
sudo perf report

# Monitor cache misses
sudo perf stat -e cache-misses,cache-references sudo testpmd -l 0-1 -n 2 -- -i
```

### 3. Debug Tools

```bash
# Check DPDK logs
dmesg | grep -i dpdk

# Debug hugepages allocation
cat /proc/buddyinfo
cat /proc/pagetypeinfo

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -name "*" | sort -V
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Hugepages Not Available

```bash
# Check hugepages support
grep -i huge /proc/cpuinfo

# Verify hugepages mount
mount | grep huge

# Check kernel parameters
cat /proc/cmdline | grep hugepages
```

#### 2. Device Binding Fails

```bash
# Check device driver
lspci -k -s $PCI_ADDRESS

# Verify IOMMU support
dmesg | grep -i iommu

# Check vfio permissions
ls -la /dev/vfio/
```

#### 3. Application Crashes

```bash
# Check core dumps
ulimit -c unlimited
echo "/tmp/core.%e.%p" | sudo tee /proc/sys/kernel/core_pattern

# Debug with gdb
gdb your-dpdk-app core.file
```

#### 4. Poor Performance

```bash
# Check CPU frequency
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Verify NUMA placement
numactl --show

# Check interrupt distribution
cat /proc/interrupts | grep eth
```

## Security Considerations

### 1. IOMMU Configuration

```bash
# Enable IOMMU for security
sudo vim /etc/default/grub
# Add: intel_iommu=on iommu=pt (for Intel)
# Add: amd_iommu=on iommu=pt (for AMD)

sudo update-grub
sudo reboot
```

### 2. Container Security

```bash
# Use specific capabilities instead of --privileged
docker run --cap-add=IPC_LOCK \
    --cap-add=SYS_ADMIN \
    --device=/dev/hugepages \
    your-dpdk-app
```

## Automation Scripts

### 1. DPDK Setup Script

```bash
# Create automated DPDK setup script
sudo tee /usr/local/bin/dpdk-setup.sh > /dev/null << 'EOF'
#!/bin/bash

set -e

# Configuration
INTERFACE=${1:-"enp1s0f0"}
HUGEPAGES=${2:-1024}
CORES=${3:-"2-7"}

echo "Setting up DPDK for interface: $INTERFACE"

# Configure hugepages
echo $HUGEPAGES | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Load modules
modprobe uio
modprobe vfio-pci

# Bind interface
PCI_ADDRESS=$(ethtool -i $INTERFACE | grep bus-info | awk '{print $2}')
ip link set $INTERFACE down
dpdk-devbind.py --bind=vfio-pci $PCI_ADDRESS

# Set CPU governor
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

echo "DPDK setup completed for $INTERFACE ($PCI_ADDRESS)"
echo "Hugepages: $HUGEPAGES"
echo "Isolated cores: $CORES"
EOF

sudo chmod +x /usr/local/bin/dpdk-setup.sh
```

### 2. Monitoring Script

```bash
# Create DPDK monitoring script
sudo tee /usr/local/bin/dpdk-monitor.sh > /dev/null << 'EOF'
#!/bin/bash

echo "=== DPDK Status ==="
dpdk-devbind.py --status

echo -e "\n=== Hugepages Status ==="
cat /proc/meminfo | grep -i huge

echo -e "\n=== CPU Governor ==="
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort -u

echo -e "\n=== IOMMU Groups ==="
find /sys/kernel/iommu_groups/ -name "*" | wc -l
echo "IOMMU groups found"

if command -v dpdk-proc-info >/dev/null 2>&1; then
    echo -e "\n=== DPDK Process Info ==="
    dpdk-proc-info -- --stats 2>/dev/null || echo "No DPDK processes running"
fi
EOF

sudo chmod +x /usr/local/bin/dpdk-monitor.sh
```

## Integration with Homelab

DPDK can be integrated with various homelab components:

### 1. With OpenStack
- **Neutron OVS-DPDK**: High-performance virtual networking
- **Nova with SR-IOV**: Direct NIC access for VMs

### 2. With Kubernetes
- **SR-IOV CNI**: High-performance pod networking
- **Multus CNI**: Multiple network interfaces per pod

### 3. With NFV Workloads
- **VPP (Vector Packet Processing)**: High-performance router/firewall
- **DPDK-enabled VNFs**: Virtual network functions

### 4. Monitoring Integration
- **Prometheus**: DPDK metrics collection
- **Grafana**: Performance visualization
- **ELK Stack**: Log analysis

## References

- [DPDK Official Documentation](https://doc.dpdk.org/)
- [DPDK Getting Started Guide](https://doc.dpdk.org/guides/linux_gsg/)
- [Intel DPDK Performance Tuning](https://www.intel.com/content/www/us/en/developer/articles/technical/dpdk-performance-optimization-guidelines-white-paper.html)
- [Mellanox DPDK Guide](https://docs.mellanox.com/display/MLNXOFEDv461000/DPDK)
- [DPDK Sample Applications](https://doc.dpdk.org/guides/sample_app_ug/)

This guide provides comprehensive DPDK setup and configuration for high-performance packet processing in your homelab environment.
