# KinD (Kubernetes in Docker) Setup Guide for Ubuntu 24.04

This guide provides a comprehensive setup for KinD (Kubernetes in Docker) on Ubuntu 24.04, including all necessary dependencies and best practices for local Kubernetes development.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Preparation](#system-preparation)
3. [Docker Installation](#docker-installation)
4. [KinD Installation](#kind-installation)
5. [kubectl Installation](#kubectl-installation)
6. [Helm Installation](#helm-installation)
7. [Basic Cluster Creation](#basic-cluster-creation)
8. [Multi-Node Cluster Setup](#multi-node-cluster-setup)
9. [Advanced Configuration](#advanced-configuration)
10. [Cluster Management](#cluster-management)
11. [Troubleshooting](#troubleshooting)
12. [Best Practices](#best-practices)

## Prerequisites

- Ubuntu 24.04 LTS
- At least 4GB RAM (8GB+ recommended)
- 20GB+ free disk space
- Sudo privileges
- Active internet connection

## System Preparation

Update your system and install basic dependencies:

```bash
# Update package index
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential
```

## Docker Installation

KinD requires Docker to run Kubernetes clusters in containers.

### Install Docker Engine

```bash
# Create installation script
cat <<'EOF' > install_docker.sh
#!/bin/bash
set -euo pipefail

echo "Installing Docker on Ubuntu 24.04..."

# Remove old Docker packages
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install dependencies
sudo apt update
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Verify installation
docker --version
sudo docker run hello-world

echo "Docker installation completed successfully!"
echo "Please log out and log back in to use Docker without sudo"
EOF

chmod +x install_docker.sh
./install_docker.sh
```

### Configure Docker for KinD

```bash
# Configure Docker daemon for better performance
sudo mkdir -p /etc/docker
cat <<'EOF' | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

# Restart Docker to apply configuration
sudo systemctl restart docker
sudo systemctl status docker
```

**Note:** Log out and log back in to apply Docker group membership changes.

## KinD Installation

### Install Latest KinD

```bash
# Create KinD installation script
cat <<'EOF' > install_kind.sh
#!/bin/bash
set -euo pipefail

echo "Installing KinD (Kubernetes in Docker)..."

# Get the latest release version
KIND_VERSION=$(curl -s "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Installing KinD version: $KIND_VERSION"

# Download and install KinD
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version

echo "KinD installation completed successfully!"
EOF

chmod +x install_kind.sh
./install_kind.sh
```

### Verify KinD Installation

```bash
# Check KinD version
kind version

# Check available commands
kind --help
```

## kubectl Installation

### Install kubectl CLI

```bash
# Create kubectl installation script
cat <<'EOF' > install_kubectl.sh
#!/bin/bash
set -euo pipefail

echo "Installing kubectl..."

# Get the latest stable version
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
echo "Installing kubectl version: $KUBECTL_VERSION"

# Download kubectl
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

# Verify the binary (optional)
curl -LO "https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Clean up
rm kubectl kubectl.sha256

# Verify installation
kubectl version --client

echo "kubectl installation completed successfully!"
EOF

chmod +x install_kubectl.sh
./install_kubectl.sh
```

### Configure kubectl Auto-completion

```bash
# Install bash completion
sudo apt install -y bash-completion

# Add kubectl completion to your shell
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

# Apply changes
source ~/.bashrc
```

## Helm Installation

### Install Helm Package Manager

```bash
# Create Helm installation script
cat <<'EOF' > install_helm.sh
#!/bin/bash
set -euo pipefail

echo "Installing Helm..."

# Download and install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version

# Add common repositories
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update repositories
helm repo update

echo "Helm installation completed successfully!"
EOF

chmod +x install_helm.sh
./install_helm.sh
```

## Basic Cluster Creation

### Create Simple Single-Node Cluster

```bash
# Create basic cluster configuration
cat <<'EOF' > kind-basic-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-basic
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
EOF

# Create the cluster
kind create cluster --config kind-basic-config.yaml

# Verify cluster
kubectl cluster-info --context kind-kind-basic
kubectl get nodes
```

### Test Basic Cluster

```bash
# Deploy a test application
kubectl create deployment nginx --image=nginx:alpine
kubectl expose deployment nginx --port=80 --type=NodePort

# Check deployment
kubectl get pods
kubectl get services

# Port forward to access the service
kubectl port-forward service/nginx 8080:80 &

# Test the application
curl http://localhost:8080

# Clean up test deployment
kubectl delete deployment nginx
kubectl delete service nginx
```

## Multi-Node Cluster Setup

### Create Multi-Node Configuration

```bash
# Create multi-node cluster configuration
cat <<'EOF' > kind-multinode-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-multinode
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      protocol: TCP
  - role: worker
    labels:
      node-type: worker
  - role: worker
    labels:
      node-type: worker
  - role: worker
    labels:
      node-type: worker
EOF

# Create the multi-node cluster
kind create cluster --config kind-multinode-config.yaml

# Verify all nodes are ready
kubectl get nodes -o wide

# Check node labels
kubectl get nodes --show-labels
```

## Advanced Configuration

### Cluster with Persistent Volumes

```bash
# Create configuration with host path mounts
cat <<'EOF' > kind-storage-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-storage
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /tmp/kind-storage
    containerPath: /data
- role: worker
  extraMounts:
  - hostPath: /tmp/kind-storage
    containerPath: /data
EOF

# Create the storage directory
sudo mkdir -p /tmp/kind-storage
sudo chmod 777 /tmp/kind-storage

# Create cluster with storage
kind create cluster --config kind-storage-config.yaml
```

### Install Ingress Controller

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Verify ingress controller
kubectl get pods -n ingress-nginx
```

### Install MetalLB Load Balancer

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

# Configure IP address pool
docker network inspect -f '{{.IPAM.Config}}' kind
cat <<'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
```

## Cluster Management

### List All Clusters

```bash
# List existing clusters
kind get clusters

# Get cluster info for specific cluster
kubectl cluster-info --context kind-kind-multinode
```

### Switch Between Clusters

```bash
# Get current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch to different cluster
kubectl config use-context kind-kind-basic

# Verify current cluster
kubectl get nodes
```

### Export and Import Cluster Configuration

```bash
# Export kubeconfig for specific cluster
kind export kubeconfig --name kind-multinode

# Save kubeconfig to file
kind get kubeconfig --name kind-multinode > kind-multinode-kubeconfig.yaml

# Use specific kubeconfig
export KUBECONFIG=kind-multinode-kubeconfig.yaml
kubectl get nodes
```

### Cleanup Clusters

```bash
# Delete specific cluster
kind delete cluster --name kind-basic

# Delete all clusters
kind delete clusters --all

# Verify clusters are deleted
kind get clusters

# Clean up Docker containers (if needed)
docker system prune -f
```

## Troubleshooting

### Common Issues and Solutions

#### Docker Permission Issues

```bash
# If you get permission denied errors
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker access
docker ps
```

#### Cluster Creation Failures

```bash
# Check Docker status
sudo systemctl status docker

# Check available resources
df -h
free -h

# Check Docker logs
sudo journalctl -u docker.service -f

# Clean up failed cluster
kind delete cluster --name <cluster-name>
docker system prune -f
```

#### Pod Scheduling Issues

```bash
# Check node status
kubectl get nodes
kubectl describe nodes

# Check pod events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods
```

### Debug Cluster Issues

```bash
# Get cluster logs
kind export logs /tmp/kind-logs

# Check KinD cluster status
docker ps -a | grep kind

# Access cluster node directly
docker exec -it kind-control-plane bash

# Check kubelet logs
docker exec -it kind-control-plane journalctl -u kubelet -f
```

## Best Practices

### Resource Management

1. **Allocate sufficient resources:**
   - At least 4GB RAM for single node
   - 8GB+ RAM for multi-node clusters
   - Monitor Docker resource usage

2. **Clean up regularly:**
   - Delete unused clusters
   - Prune Docker images and containers
   - Monitor disk space usage

### Development Workflow

1. **Use consistent naming:**
   - Follow naming conventions for clusters
   - Use descriptive cluster names
   - Document cluster purposes

2. **Version control configurations:**
   - Store KinD configs in Git
   - Use environment-specific configs
   - Document configuration changes

3. **Security considerations:**
   - Don't expose clusters to external networks
   - Use RBAC for access control
   - Regularly update KinD and kubectl

### Performance Optimization

```bash
# Optimize Docker for KinD
cat <<'EOF' | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "data-root": "/var/lib/docker",
  "registry-mirrors": [
    "https://mirror.gcr.io"
  ]
}
EOF

sudo systemctl restart docker
```

### Useful Aliases and Functions

```bash
# Add to ~/.bashrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Function to quickly create a test pod
function ktest() {
    kubectl run test-pod --image=nginx:alpine --rm -it -- /bin/sh
}

# Function to get pod logs
function klogs() {
    kubectl logs -f $1
}
```

This completes the comprehensive KinD setup guide. The documentation now provides a clear, structured approach to setting up and managing Kubernetes clusters using KinD on Ubuntu 24.04.