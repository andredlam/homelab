# NFS Server Setup on Ubuntu 24.04

This guide provides step-by-step instructions for setting up an NFS (Network File System) server on Ubuntu 24.04 LTS.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Security](#security)
- [Client Access](#client-access)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## Prerequisites

### System Requirements
- Ubuntu 24.04 LTS server
- Minimum 2GB RAM
- At least 10GB free disk space for NFS exports
- Network connectivity to client machines
- Static IP address (recommended)

### Network Information
```bash
# Example network configuration
NFS_SERVER_IP=10.0.0.100
NFS_EXPORT_PATH=/export
CLIENT_NETWORK=10.0.0.0/24
```

## Installation

### 1. Update System Packages
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install NFS Server Packages
```bash
# Install NFS kernel server and utilities
sudo apt install -y nfs-kernel-server nfs-common

# Verify installation
sudo systemctl status nfs-kernel-server
```

### 3. Create Export Directory
```bash
# Create the main export directory
sudo mkdir -p /export

# Create subdirectories for different uses
sudo mkdir -p /export/shared
sudo mkdir -p /export/backups
sudo mkdir -p /export/data
sudo mkdir -p /export/kubernetes

# Set ownership and permissions
sudo chown -R nobody:nogroup /export
sudo chmod -R 755 /export
```

## Configuration

### 1. Configure NFS Exports
Edit the NFS exports configuration file:

```bash
sudo nano /etc/exports
```

Add your export configurations:

```bash
# /etc/exports configuration examples

# Basic export with read-write access for specific network
/export/shared    10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)

# Read-only export for backups
/export/backups   10.0.0.0/24(ro,sync,no_subtree_check,root_squash)

# Kubernetes-specific export with full permissions
/export/kubernetes 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash,insecure)

# Single host access
/export/data      10.0.0.120(rw,sync,no_subtree_check,no_root_squash)

# Multiple networks
/export/shared    10.0.0.0/24(rw,sync,no_subtree_check) 192.168.1.0/24(rw,sync,no_subtree_check)
```

### 2. Export Options Explained

| Option | Description |
|--------|-------------|
| `rw` | Read-write access |
| `ro` | Read-only access |
| `sync` | Write changes to disk before replying |
| `async` | Write changes to disk asynchronously (faster but less safe) |
| `no_subtree_check` | Disable subtree checking (recommended) |
| `subtree_check` | Enable subtree checking |
| `no_root_squash` | Allow root user on client to access as root |
| `root_squash` | Map root user to anonymous user (default) |
| `all_squash` | Map all users to anonymous user |
| `insecure` | Allow connections from ports > 1024 |
| `secure` | Require connections from ports < 1024 (default) |

### 3. Apply Export Configuration
```bash
# Export the file systems
sudo exportfs -arv

# Verify exports
sudo exportfs -s
```

### 4. Configure NFS Services
```bash
# Enable and start NFS services
sudo systemctl enable nfs-kernel-server
sudo systemctl enable rpcbind
sudo systemctl enable nfs-server

# Start services
sudo systemctl start rpcbind
sudo systemctl start nfs-kernel-server
sudo systemctl start nfs-server

# Check service status
sudo systemctl status nfs-kernel-server
sudo systemctl status rpcbind
```

## Security

### 1. Firewall Configuration
```bash
# Install UFW if not already installed
sudo apt install -y ufw

# Allow NFS services through firewall
sudo ufw allow from 10.0.0.0/24 to any port nfs
sudo ufw allow from 10.0.0.0/24 to any port 111
sudo ufw allow from 10.0.0.0/24 to any port 2049
sudo ufw allow from 10.0.0.0/24 to any port 32765:32768

# Or allow specific ports manually
sudo ufw allow 111/tcp
sudo ufw allow 111/udp
sudo ufw allow 2049/tcp
sudo ufw allow 2049/udp
sudo ufw allow 32765:32768/tcp
sudo ufw allow 32765:32768/udp

# Enable firewall
sudo ufw enable

# Check firewall status
sudo ufw status
```

### 2. Configure Static Ports (Optional but Recommended)
Edit `/etc/default/nfs-kernel-server`:

```bash
sudo nano /etc/default/nfs-kernel-server
```

Add/modify these lines:
```bash
# Static port configuration
RPCMOUNTDOPTS="--manage-gids -p 32767"
RPCNFSDOPTS="-N 2 -N 3 -N 4 -p 2049 -s -T -U"
STATDOPTS="--port 32765 --outgoing-port 32766"
```

Edit `/etc/default/nfs-common`:
```bash
sudo nano /etc/default/nfs-common
```

Add:
```bash
STATDOPTS="--port 32765 --outgoing-port 32766"
```

Restart services:
```bash
sudo systemctl restart nfs-kernel-server
sudo systemctl restart rpcbind
```

### 3. Network Security
```bash
# Create /etc/hosts.allow for additional security
sudo nano /etc/hosts.allow
```

Add:
```bash
# Allow NFS access from specific network
portmap: 10.0.0.0/24
lockd: 10.0.0.0/24
rquotad: 10.0.0.0/24
mountd: 10.0.0.0/24
statd: 10.0.0.0/24
```

Create `/etc/hosts.deny`:
```bash
sudo nano /etc/hosts.deny
```

Add:
```bash
# Deny all other access
portmap: ALL
lockd: ALL
rquotad: ALL
mountd: ALL
statd: ALL
```

## Client Access

### 1. Test NFS Server Availability
```bash
# Check RPC services
sudo rpcinfo -p localhost

# Show current exports
showmount -e localhost

# Test from client machine
showmount -e <NFS_SERVER_IP>
```

### 2. Mount from Client (Ubuntu)
```bash
# Install NFS client utilities
sudo apt install -y nfs-common

# Create mount point
sudo mkdir -p /mnt/nfs-shared

# Test mount
sudo mount -t nfs <NFS_SERVER_IP>:/export/shared /mnt/nfs-shared

# Permanent mount - add to /etc/fstab
echo "<NFS_SERVER_IP>:/export/shared /mnt/nfs-shared nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Test fstab entry
sudo mount -a
```

### 3. Mount Options for Clients
```bash
# High performance mount
sudo mount -t nfs -o vers=4.2,proto=tcp,rsize=1048576,wsize=1048576,timeo=14,intr <NFS_SERVER_IP>:/export/shared /mnt/nfs-shared

# Soft mount (recommended for non-critical data)
sudo mount -t nfs -o soft,timeo=10,retrans=2 <NFS_SERVER_IP>:/export/shared /mnt/nfs-shared

# Hard mount (recommended for critical data)
sudo mount -t nfs -o hard,timeo=600,retrans=5 <NFS_SERVER_IP>:/export/shared /mnt/nfs-shared
```

## Troubleshooting

### 1. Common Issues and Solutions

#### Service Not Starting
```bash
# Check service status
sudo systemctl status nfs-kernel-server

# Check logs
sudo journalctl -u nfs-kernel-server -f

# Restart services in order
sudo systemctl restart rpcbind
sudo systemctl restart nfs-kernel-server
```

#### Permission Denied
```bash
# Check export permissions
sudo exportfs -s

# Verify directory permissions
ls -la /export/

# Check if client IP is in allowed range
sudo cat /etc/exports
```

#### Connection Issues
```bash
# Test network connectivity
ping <CLIENT_IP>

# Check if ports are open
sudo netstat -tulpn | grep -E '(111|2049)'

# Test RPC services
rpcinfo -p <NFS_SERVER_IP>
```

### 2. Diagnostic Commands
```bash
# Show all exports
sudo exportfs -v

# Show mounted filesystems
sudo mount | grep nfs

# Check NFS statistics
sudo nfsstat

# Monitor NFS activity
sudo nfsiostat 1

# Check client connections
sudo ss -a | grep :2049
```

### 3. Log Files
```bash
# System logs
sudo tail -f /var/log/syslog | grep nfs

# Kernel logs
sudo dmesg | grep -i nfs

# Authentication logs
sudo tail -f /var/log/auth.log
```

## Maintenance

### 1. Regular Maintenance Tasks

#### Update Exports
```bash
# After modifying /etc/exports
sudo exportfs -arv

# Force re-export
sudo exportfs -ra
```

#### Monitor Disk Usage
```bash
# Check disk usage of export directories
sudo du -sh /export/*

# Monitor disk space
df -h /export
```

#### Backup Configuration
```bash
# Backup NFS configuration
sudo cp /etc/exports /etc/exports.backup.$(date +%Y%m%d)
sudo cp /etc/default/nfs-kernel-server /etc/default/nfs-kernel-server.backup.$(date +%Y%m%d)
```

### 2. Performance Tuning

#### Optimize NFS Parameters
Edit `/etc/default/nfs-kernel-server`:
```bash
# Increase number of server threads for better performance
RPCNFSDCOUNT=16

# Optimize TCP settings
echo 'net.core.rmem_default = 262144' | sudo tee -a /etc/sysctl.conf
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_default = 262144' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf

# Apply sysctl changes
sudo sysctl -p
```

#### Monitor Performance
```bash
# Install performance monitoring tools
sudo apt install -y nfs-utils

# Monitor I/O statistics
iostat -x 1

# Monitor network traffic
sudo iftop -i <network_interface>
```

### 3. Security Updates
```bash
# Regular security updates
sudo apt update && sudo apt upgrade -y

# Check for NFS-specific updates
sudo apt list --upgradable | grep nfs
```

## Advanced Configuration

### 1. NFS Version 4 Specific Configuration
```bash
# Configure NFSv4 domain
echo "Domain = example.com" | sudo tee -a /etc/idmapd.conf

# Restart idmapd service
sudo systemctl restart nfs-idmapd
```

### 2. Kerberos Authentication (Optional)
```bash
# Install Kerberos packages
sudo apt install -y krb5-user

# Configure Kerberos (requires additional setup)
# This is beyond the scope of this basic guide
```

### 3. High Availability Setup
For production environments, consider:
- Setting up NFS clustering with Pacemaker
- Using DRBD for data replication
- Implementing load balancing

## Example Configurations

### 1. Home Lab Setup
```bash
# /etc/exports for home lab
/export/media     192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/export/backups   192.168.1.0/24(rw,sync,no_subtree_check,root_squash)
/export/shared    192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
```

### 2. Kubernetes Storage
```bash
# /etc/exports for Kubernetes
/export/k8s-pv    10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash,insecure)
```

### 3. Development Environment
```bash
# /etc/exports for development
/export/code      10.0.0.0/24(rw,async,no_subtree_check,no_root_squash)
/export/logs      10.0.0.0/24(rw,sync,no_subtree_check,root_squash)
```

## Useful Scripts

### 1. NFS Health Check Script
```bash
#!/bin/bash
# nfs-health-check.sh
echo "=== NFS Server Health Check ==="
echo "Services Status:"
systemctl is-active nfs-kernel-server
systemctl is-active rpcbind

echo -e "\nExports:"
exportfs -s

echo -e "\nDisk Usage:"
df -h /export

echo -e "\nActive Connections:"
ss -a | grep :2049 | wc -l
```

### 2. Export Backup Script
```bash
#!/bin/bash
# backup-exports.sh
BACKUP_DIR="/root/nfs-backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
cp /etc/exports $BACKUP_DIR/exports_$DATE
cp /etc/default/nfs-kernel-server $BACKUP_DIR/nfs-kernel-server_$DATE

echo "NFS configuration backed up to $BACKUP_DIR"
```

## References

- [Ubuntu NFS Documentation](https://ubuntu.com/server/docs/service-nfs)
- [NFS HOW-TO Guide](https://nfs.sourceforge.net/nfs-howto/)
- [Linux NFS Performance Tuning](https://wiki.linux-nfs.org/wiki/index.php/Performance)
- [NFS Security Best Practices](https://wiki.linux-nfs.org/wiki/index.php/NFS_security)

## Support

For additional help:
- Ubuntu Community: [https://ubuntu.com/community](https://ubuntu.com/community)
- NFS Mailing List: [linux-nfs@vger.kernel.org](mailto:linux-nfs@vger.kernel.org)
- Stack Overflow: [nfs tag](https://stackoverflow.com/questions/tagged/nfs)

---

**Note**: Always test NFS configurations in a development environment before deploying to production. Regular backups of both configuration files and exported data are essential.