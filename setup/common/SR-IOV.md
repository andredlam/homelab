# SR-IOV Configuration for AMD + ConnectX-3

## Prerequisites
- Ubuntu Server 24.04 LTS
- Mellanox ConnectX-3 NIC
- AMD CPU with IOMMU support
- BIOS settings:
  - SR-IOV: Enabled
  - AMD-Vi (IOMMU): Enabled
  - Virtualization: Enabled

## Enable SR-IOV on Ubuntu
```shell
# Edit the GRUB configuration file
$ sudo vi /etc/default/grub
# Add the following line to enable SR-IOV
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt pci=realloc"

# Update the GRUB configuration
$ sudo update-grub
# Reboot the system to apply the changes
$ sudo reboot
```

## 2. Install Mellanox DOCA
```bash
# Download the DOCA package for Ubuntu 24.04
https://developer.nvidia.com/networking/doca

https://developer.nvidia.com/doca-downloads?deployment_platform=Host-Server&deployment_package=DOCA-Host&target_os=Linux&Architecture=x86_64&Profile=doca-all&Distribution=Ubuntu&version=24.04&installer_type=deb_local

```

# After reboot, check if the IOMMU is enabled
$ dmesg | grep -i iommu
# You should see output indicating that IOMMU is enabled
# Check if the SR-IOV is supported by the NIC
$ lspci | grep -i ethernet
# Look for a line that mentions "SR-IOV" or "Virtual Functions"
# If SR-IOV is supported, you can proceed with the configuration


wget https://linux.mellanox.com/public/repo/mlnx_ofed/latest/ubuntu24.04/mlnx-ofed-all_24.10-1.1.4.0_all.deb

# Install the required packages
$ sudo apt install -y linux-tools-generic linux-cloud-tools-generic
# Enable SR-IOV in the kernel
$ sudo modprobe -r ixgbe
$ sudo modprobe ixgbe max_vfs=8  # Set the number of VFs (Virtual Functions) to 8
# Verify that SR-IOV is enabled
$ sudo lspci | grep -i virtual
# Check the number of VFs
$ sudo ethtool -i eth0 | grep vf
# Configure the VFs
$ sudo ip link set eth0 vf 0 mac 00:11:22:33:44:55
$ sudo ip link set eth0 vf 0 vlan 100
$ sudo ip link set eth0 vf 0 spoofchk on
# Verify the configuration
$ sudo ip link show eth0
# Check the VFs configuration
$ sudo ethtool -i eth0 | grep vf
# Check the status of the VFs
$ sudo ethtool -S eth0 | grep vf
# Check the SR-IOV configuration
$ cat /sys/class/net/eth0/device/sriov_numvfs
# Check the number of VFs
$ cat /sys/class/net/eth0/device/sriov_totalvfs
# Check the VFs configuration
$ cat /sys/class/net/eth0/device/sriov/vfinfo
# Check the VFs status
$ cat /sys/class/net/eth0/device/sriov/vfstatus
# Check the VFs MAC addresses
$ cat /sys/class/net/eth0/device/sriov/vfmac
# Check the VFs VLAN configuration
$ cat /sys/class/net/eth0/device/sriov/vfvlan
# Check the VFs spoof checking configuration
$ cat /sys/class/net/eth0/device/sriov/vfspoofchk
# Check the VFs link status
$ cat /sys/class/net/eth0/device/sriov/vflink
# Check the VFs link speed
$ cat /sys/class/net/eth0/device/sriov/vfspeed
# Check the VFs link duplex
$ cat /sys/class/net/eth0/device/sriov/vfduplex
# Check the VFs link autonegotiation
$ cat /sys/class/net/eth0/device/sriov/vfautoneg
# Check the VFs link speed and duplex
$ sudo ethtool eth0 | grep -i speed
$ sudo ethtool eth0 | grep -i duplex
# Check the VFs link autonegotiation
$ sudo ethtool eth0 | grep -i autoneg
# Check the VFs link status
$ sudo ethtool eth0 | grep -i link

```