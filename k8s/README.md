# Kubernetes Cluster Setup Guide

This guide walks you through setting up a 6-node Kubernetes cluster with 3 master nodes and 3 worker nodes for high availability on Ubuntu 24.04 LTS.

## Prerequisites

### Hardware Requirements
- 6 Virtual Machines (or physical machines)
- **Master Nodes**: Minimum 2 CPU cores, 4GB RAM, 20GB disk space each
- **Worker Nodes**: Minimum 2 CPU cores, 4GB RAM, 50GB disk space each
- All nodes should be on the same network with static IP addresses

### Software Requirements
- **Ubuntu 24.04 LTS** on all nodes
- SSH access to all nodes with sudo privileges
- Internet connectivity on all nodes
- Unique MAC address and product_uuid for every node

## Network Planning

| Node Type | Hostname | IP Address | Role |
|-----------|----------|------------|------|
| Master 1  | k8s-master-1 | 10.0.0.120 | Control Plane (Primary) |
| Master 2  | k8s-master-2 | 10.0.0.245 | Control Plane |
| Master 3  | k8s-master-3 | 10.0.0.184 | Control Plane |
| Worker 1  | k8s-worker-1 | 10.0.0.191 | Worker Node |
| Worker 2  | k8s-worker-2 | 10.0.0.175 | Worker Node |
| Worker 3  | k8s-worker-3 | 10.0.0.204 | Worker Node |

**Note**: The first master node (k8s-master-1) will serve as the initial control plane endpoint.

## Step 1: Prepare All Nodes

Run these commands on **all 6 nodes**:

### 1.1 Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
```

### 1.2 Set Hostnames
```bash
# On each node, set the appropriate hostname
# Master nodes:
sudo hostnamectl set-hostname k8s-master-1  # For master-1
sudo hostnamectl set-hostname k8s-master-2  # For master-2
sudo hostnamectl set-hostname k8s-master-3  # For master-3

# Worker nodes:
sudo hostnamectl set-hostname k8s-worker-1  # For worker-1
sudo hostnamectl set-hostname k8s-worker-2  # For worker-2
sudo hostnamectl set-hostname k8s-worker-3  # For worker-3
```

### 1.3 Configure /etc/hosts
Add this to `/etc/hosts` on all nodes:
```bash
sudo tee -a /etc/hosts <<EOF
10.0.0.120 k8s-master-1
10.0.0.245 k8s-master-2
10.0.0.184 k8s-master-3
10.0.0.191 k8s-worker-1
10.0.0.175 k8s-worker-2
10.0.0.204 k8s-worker-3
EOF
```

### 1.4 Disable Swap
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Verify swap is disabled
free -h
```

### 1.5 Configure Kernel Modules
```bash
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Verify modules are loaded
lsmod | grep br_netfilter
lsmod | grep overlay
```

### 1.6 Configure Kernel Parameters
```bash
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Verify settings
sudo sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

## Step 2: Install Container Runtime (Containerd)

Run on **all nodes**:

### 2.1 Install Containerd
```bash
# Install Docker's official GPG key
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources for Ubuntu 24.04
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y containerd.io
```

### 2.2 Configure Containerd
```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Enable SystemdCgroup
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd
```

## Step 3: Install Kubernetes Components

Run on **all nodes**:

### 3.1 Add Kubernetes Repository (Updated for Ubuntu 24.04)
```bash
# Download the public signing key for the Kubernetes package repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the appropriate Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

### 3.2 Install Kubernetes
```bash
sudo apt-get update

# Install specific version for stability
sudo apt-get install -y kubelet=1.29.0-1.1 kubeadm=1.29.0-1.1 kubectl=1.29.0-1.1

# Hold packages to prevent automatic updates
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable kubelet
```

## Step 4: Initialize the First Master Node

On **k8s-master-1** only:

### 4.1 Create kubeadm Config
```bash
sudo tee /etc/kubernetes/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "1.29.0"
controlPlaneEndpoint: "k8s-master-1:6443"
networking:
  serviceSubnet: "10.96.0.0/16"
  podSubnet: "10.244.0.0/16"
  dnsDomain: "cluster.local"
etcd:
  local:
    dataDir: "/var/lib/etcd"
apiServer:
  advertiseAddress: "10.0.0.120"
  bindPort: 6443
  certSANs:
  - "10.0.0.120"
  - "k8s-master-1"
  - "10.0.0.245"
  - "k8s-master-2"
  - "10.0.0.184"
  - "k8s-master-3"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "10.0.0.120"
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF
```

### 4.2 Initialize the Cluster
```bash
sudo kubeadm init --config=/etc/kubernetes/kubeadm-config.yaml --upload-certs

# Save the join commands that appear at the end of the output!
# You'll need both the master join command and worker join command

#EXAMPLE OF JOIN COMMANDS:
# kubeadm join k8s-master-1:6443 --token 5zzm2h.32q0hej0pi72d0oo \
# 	--discovery-token-ca-cert-hash \ 
#     sha256:368057dc67f5fdb8014df896fd7bc7b578bc477c89ae9bf6968c7887aa8da240
# --control-plane --certificate-key 8d891ac63d512eb63ee82cdc2bd060d1aa06279c59a9e5d449ae705d3908b3f5
```

### 4.3 Configure kubectl for regular user
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Test kubectl
kubectl get nodes
```

### 4.4 Install CNI Plugin (Flannel)
```bash
# Apply Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for flannel pods to be ready
kubectl get pods -n kube-flannel -w
```

## Step 5: Join Additional Master Nodes

Copy the **control-plane join command** from the output of step 4.2. Run on **k8s-master-2** and **k8s-master-3**:

```bash
# Example command (use the actual output from your kubeadm init)
sudo kubeadm join k8s-master-1:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash> \
    --control-plane --certificate-key <cert-key>
```

Configure kubectl on additional masters:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
kubectl get nodes
```

## Step 6: Join Worker Nodes

Copy the **worker join command** from the output of step 4.2. Run on **all worker nodes** (k8s-worker-1, k8s-worker-2, k8s-worker-3):

```bash
# Example command (use the actual output from your kubeadm init)
sudo kubeadm join k8s-master-1:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

## Step 7: Verify Cluster

From any master node:

```bash
# Check all nodes
kubectl get nodes -o wide

# Check cluster info
kubectl cluster-info

# Check system pods
kubectl get pods --all-namespaces

# Check node status in detail
kubectl describe nodes

# Verify all nodes are Ready
kubectl get nodes --watch
```

Expected output should show all 6 nodes in "Ready" status.

## Step 8: Configure High Availability (Optional)

### 8.1 Update kubeconfig on all master nodes
For true HA, you can update the kubeconfig to include all master nodes:

```bash
# On each master node, update the server endpoint to include all masters
kubectl config set-cluster kubernetes --server=https://k8s-master-1:6443

# Alternatively, you can use a round-robin DNS or external load balancer later
```

### 8.2 Test API Server Accessibility
```bash
# Test from any node
curl -k https://k8s-master-1:6443/healthz
curl -k https://k8s-master-2:6443/healthz
curl -k https://k8s-master-3:6443/healthz
```

## Step 9: Install Additional Components

### 9.1 Install MetalLB for LoadBalancer Services
```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

# Configure IP pool (adjust range as needed)
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.0.200-10.0.0.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
```

### 9.2 Install Ingress Controller (NGINX)
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 9.3 Install Metrics Server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for local development (if needed)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'
```

## Step 10: Test Your Cluster

### 10.1 Deploy a Test Application
```bash
# Create a test deployment
kubectl create deployment nginx-test --image=nginx:latest

# Scale the deployment
kubectl scale deployment nginx-test --replicas=6

# Expose as a service
kubectl expose deployment nginx-test --port=80 --type=LoadBalancer

# Check the service
kubectl get services
kubectl get pods -o wide
```

### 10.2 Test Pod Scheduling Across Nodes
```bash
# Check where pods are scheduled
kubectl get pods -o wide

# Verify pods are distributed across nodes
kubectl get pods -o wide | grep nginx-test

# Check node capacity
kubectl describe nodes | grep -A 5 "Capacity:"
```

## Troubleshooting

### Common Issues

1. **Nodes not joining**: 
   - Check firewall rules (ports 6443, 2379-2380, 10250-10252, 10256)
   - Verify time synchronization across nodes
   - Check network connectivity between nodes
   - Ensure hostname resolution is working

2. **Pods not starting**: 
   - Check CNI plugin installation
   - Verify node resources
   - Check containerd service status

3. **Master nodes not accessible**: 
   - Verify all master nodes have the same cluster certificates
   - Check if etcd is running on all masters
   - Ensure API server is binding to the correct interface

### Useful Commands

```bash
# Reset a node (if needed)
sudo kubeadm reset --cleanup-tmp-dir
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube/config
sudo systemctl restart containerd

# Generate new join token
kubeadm token create --print-join-command

# Get cluster certificates for additional masters
sudo kubeadm init phase upload-certs --upload-certs

# Check kubelet logs
sudo journalctl -xeu kubelet

# Check containerd logs
sudo journalctl -xeu containerd

# Check API server logs
sudo journalctl -xeu kube-apiserver
```

### Firewall Configuration (if using UFW)
```bash
# On master nodes
sudo ufw allow 6443/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10251/tcp
sudo ufw allow 10252/tcp
sudo ufw allow 10256/tcp

# On worker nodes
sudo ufw allow 10250/tcp
sudo ufw allow 10256/tcp
sudo ufw allow 30000:32767/tcp

# On all nodes
sudo ufw allow from 10.244.0.0/16  # Pod network
sudo ufw allow from 10.96.0.0/16   # Service network
```

## Security Considerations

1. **Network Security**:
   - Use proper firewall rules
   - Implement network policies
   - Secure inter-node communication

2. **Access Control**:
   - RBAC is enabled by default
   - Create service accounts with minimal permissions
   - Use strong authentication

3. **etcd Security**:
   - etcd is secured with TLS by default
   - Regular backups are essential
   - Restrict access to etcd

4. **Regular Updates**:
   - Keep Ubuntu 24.04 updated
   - Plan Kubernetes version upgrades
   - Monitor security advisories

## High Availability Considerations

Since we're not using an external load balancer:

1. **API Server Access**: Applications should be configured to use all master nodes' IP addresses
2. **DNS Configuration**: Consider setting up DNS records that point to all master nodes
3. **Client Configuration**: kubectl and applications should be configured with multiple server endpoints

### Setting up DNS Round Robin (Optional)
```bash
# Add to /etc/hosts on client machines
echo "10.0.0.120 k8s-api" | sudo tee -a /etc/hosts
echo "10.0.0.245 k8s-api" | sudo tee -a /etc/hosts  
echo "10.0.0.184 k8s-api" | sudo tee -a /etc/hosts
```

## Backup Strategy

### 1. etcd Backup
```bash
# Create backup script
sudo tee /usr/local/bin/etcd-backup.sh <<EOF
#!/bin/bash
BACKUP_DIR="/backup/etcd"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

ETCDCTL_API=3 etcdctl snapshot save \$BACKUP_DIR/etcd-snapshot-\$DATE.db \\
  --endpoints=https://127.0.0.1:2379 \\
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \\
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \\
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key

# Keep only last 7 days
find \$BACKUP_DIR -name "*.db" -mtime +7 -delete
EOF

sudo chmod +x /usr/local/bin/etcd-backup.sh

# Set up cron job for daily backups (run on all master nodes)
echo "0 2 * * * root /usr/local/bin/etcd-backup.sh" | sudo tee -a /etc/crontab
```

### 2. Kubernetes Configuration Backup
```bash
# Backup Kubernetes configs
sudo mkdir -p /backup/kubernetes
sudo cp -r /etc/kubernetes /backup/kubernetes/kubernetes-$(date +%Y%m%d)
```

## Monitoring and Logging

Consider installing:

### Prometheus & Grafana
```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

### ELK Stack or Loki for Logging
```bash
# Example: Install Loki-stack
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack -n monitoring
```

## Cluster Maintenance

### Upgrading Kubernetes
```bash
# Check current version
kubectl version --short

# Plan upgrade (run on first master)
sudo kubeadm upgrade plan

# Upgrade master nodes (one at a time, starting with k8s-master-1)
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.29.1-1.1
sudo apt-mark hold kubeadm

# Apply upgrade (only on first master)
sudo kubeadm upgrade apply v1.29.1

# On other masters, run:
sudo kubeadm upgrade node

# Upgrade kubelet and kubectl on all nodes
sudo apt-mark unhold kubelet kubectl
sudo apt-get update && sudo apt-get install -y kubelet=1.29.1-1.1 kubectl=1.29.1-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl restart kubelet
```

Your highly available Kubernetes cluster on Ubuntu 24.04 is now ready for production workloads!

## Next Steps

1. **Set up CI/CD pipelines** to deploy applications
2. **Configure monitoring and alerting**
3. **Implement backup and disaster recovery procedures**
4. **Set up cluster autoscaling** if using cloud infrastructure
5. **Configure persistent storage** solutions
6. **Implement security scanning** and compliance checks
7. **Consider setting up external load balancer** for true HA in production

## Useful Resources

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Ubuntu 24.04 Release Notes](https://releases.ubuntu.com/24.04/)
- [kubeadm Troubleshooting Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)