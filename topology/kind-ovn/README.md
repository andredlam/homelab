# KinD with OVN CNI Plugin

## Prerequisites
- Ubuntu 24.04
- Docker
- KinD
- kubectl

## References
- https://ovn-kubernetes.io/


## Installation Steps

### 1. Install Dependencies
-> Look at setup/common/k8s-kind/SETUP.md for detailed instructions on installing Docker, KinD, and kubectl.

### 2. Create a KinD Cluster with OVN CNI
```bash
# Create a KinD kind-config.yaml file
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ovn-cluster
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
```

### Disable firewall
```bash
# Configure the firewall to avoid issues with OVN networking
sudo ufw allow 11337/tcp
sudo ufw enable
sudo ufw status numbered
```




# Clone the OVN Kubernetes repository
git clone https://github.com/ovn-kubernetes/ovn-kubernetes.git

cd ovn-kubernetes

# Install OVN using the quick start
kubectl apply -f dist/images/ovn-daemonset.yaml