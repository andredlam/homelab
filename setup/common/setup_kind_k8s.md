### Install Docker on Ubuntu
```shell
cat <<'EOF' >> install_docker.sh
sudo apt -y update

sudo apt -y install \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt -y update
sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
sudo systemctl restart docker
sudo systemctl status docker
EOF

chmod +x install_docker.sh
bash install_docker.sh


# exit and login again to apply group changes 
```

### Install KinD
```shell
cat <<'EOF' >> install_kind.sh
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version
EOF

chmod +x install_kind.sh
bash install_kind.sh
```

### Install Helm chart
```shell
cat <<'EOF' >> install_helm.sh
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
EOF
chmod +x install_helm.sh
bash install_helm.sh

# create kind-config.yaml
cat <<'EOF' >> kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-cluster
networking:
  apiServerAddress: "127.0.0.1"
EOF

kind create cluster --config kind-config.yaml
```

### Install Kubernetes CLI (kubectl)
```shell
cat <<'EOF' >> install_kubectl.sh
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg
sudo curl -fsSL https://how t

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
EOF

chmod +x install_kubectl.sh
bash install_kubectl.sh

kubectl cluster-info
kubectl get nodes
```


### Cleanup KinD Cluster
```shell
# List existing clusters
kind get clusters

# Delete specific cluster
kind delete cluster --name kind-cluster

# Or delete all clusters
kind delete clusters --all

# Verify clusters are deleted
kind get clusters
```

### Create Multi-Node KinD Cluster
```shell
# Create kind-config.yaml with multiple workers
cat <<'EOF' >> kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind-cluster
networking:
  apiServerAddress: "127.0.0.1"
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

# Create cluster
kind create cluster --config kind-config.yaml

# Verify nodes
kubectl get nodes

# Check node details
kubectl describe nodes
```