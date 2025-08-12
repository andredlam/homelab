# Homelab Helm Chart

A comprehensive Helm chart for deploying a full-stack application with monitoring and data storage capabilities. This chart supports both development (Kind) and production Kubernetes environments.

## 🚀 Quick Start

### Development Environment (Kind)
```bash
cd helm
make setup-dev    # Creates Kind cluster and loads resources
make install-dev  # Deploys the application
```

### Production Environment
```bash
cd helm
make init-prod    # One-time setup instructions
make setup-prod   # Configures production environment
make install-prod # Deploys to production
```

## 📋 Prerequisites

### Development (Kind)
- Docker Desktop or Docker Engine
- Kind (Kubernetes in Docker)
- Helm 3.x
- kubectl
- NFS server accessible at `10.0.0.137:/export`

### Production
- Access to a production Kubernetes cluster
- kubectl configured for your cluster
- Helm 3.x
- NFS server accessible at `10.0.0.137:/export`

## 🏗️ Architecture

### Components
- **Frontend** - React application served by Nginx
- **Backend** - FastAPI Python web server
- **Database** - InfluxDB v2 for time-series data
- **Monitoring** - Grafana for metrics and dashboards
- **Storage** - NFS-backed persistent volumes
- **Ingress** - Nginx Ingress Controller for routing

### Infrastructure
- **Development**: Kind cluster with local Docker images
- **Production**: External Kubernetes cluster
- **Storage**: NFS server provides persistent storage for both environments

## 🔧 Configuration

### Environment Variables
```bash
ENV=dev|prod          # Environment selection (default: dev)
CLUSTER_NAME          # Kubernetes cluster name
HELM_RELEASE_NAME     # Helm release name (sample-dev or sample-prod)
KUBECONFIG           # Path to kubeconfig file
```

### NFS Configuration
```bash
NFS_IP=10.0.0.137         # NFS server IP address
NFS_PATH=/export          # NFS export path
LOCAL_NFS_PATH=/nfs/export # Local mount point
```

## 📁 Directory Structure

```
helm/
├── Makefile              # Main deployment automation
├── kind-config.yaml      # Kind cluster configuration
├── sample/               # Main Helm chart
│   ├── Chart.yaml
│   ├── values.yaml       # Default values
│   ├── charts/          # Dependency charts (Grafana, InfluxDB, Nginx)
│   └── templates/       # Kubernetes manifests
└── environments/        # Environment-specific configurations
    ├── dev/
    │   ├── values/
    │   │   └── values.yaml # Dev-specific values
    │   └── templates/
    │       ├── pv.yaml     # Dev persistent volume
    │       └── pvc.yaml    # Dev persistent volume claim
    └── prod/
        ├── values/
        │   └── values.yaml # Prod-specific values
        └── templates/
            ├── pv.yaml     # Prod persistent volume
            └── pvc.yaml    # Prod persistent volume claim
```

## 🛠️ Available Make Targets

### Environment Setup
```bash
make setup-dev          # Setup development environment
make setup-prod         # Setup production environment
make init-prod          # Initialize production configuration
```

### Application Deployment
```bash
make install-dev        # Install application in dev
make install-prod       # Install application in prod
make install ENV=dev    # Install with explicit environment
```

### Cleanup
```bash
make clean-dev          # Clean dev environment and Kind cluster
make clean-prod         # Clean prod environment (keeps cluster)
make uninstall ENV=dev  # Uninstall Helm release only
```

## 🐳 Docker Images

The chart uses custom Docker images that are built from the `/app` directory:

### Frontend Image
- **Base**: Node.js (build) + Nginx (runtime)
- **Location**: `../app/frontend/`
- **Registry**: Loaded into Kind or external registry

### Backend Image  
- **Base**: Python 3.11-slim
- **Framework**: FastAPI
- **Location**: `../app/backend/`
- **Registry**: Loaded into Kind or external registry

## 💾 Storage

### NFS Integration
- **Server**: `10.0.0.137:/export`
- **Local Mount**: `/nfs/export`
- **Purpose**: 
  - Helm chart storage (`/nfs/export/helmcharts/*.tgz`)
  - Docker image archives (`/nfs/export/images/*.tar`)
  - Application data persistence

### Persistent Volumes
- **InfluxDB**: Uses NFS-backed PVC for data persistence
- **Grafana**: Configuration and dashboard storage
- **Application**: User data and uploads

## 🔐 Production Setup

### Initial Configuration
1. **Prepare kubeconfig**:
   ```bash
   kubectl config view --raw > ~/.kube/prod-config
   ```

2. **Initialize production**:
   ```bash
   make init-prod
   ```

3. **Deploy application**:
   ```bash
   make setup-prod
   make install-prod
   ```

### Production Considerations
- Ensure proper RBAC permissions
- Configure ingress with proper TLS certificates
- Set appropriate resource limits and requests
- Configure monitoring and alerting
- Backup strategy for persistent data

## 🔍 Troubleshooting

### Common Issues

**Kind cluster not starting**:
```bash
kind delete cluster --name kind-cluster
make setup-dev
```

**Images not found in cluster**:
```bash
# Check loaded images
docker exec -it kind-cluster-control-plane crictl images

# Rebuild and reload images
cd ../app && make build-all
make setup-dev
```

**NFS mount issues**:
```bash
# Check NFS connectivity
sudo umount /nfs/export
sudo mount -t nfs 10.0.0.137:/export /nfs/export
```

**Production cluster connection**:
```bash
# Verify kubeconfig
kubectl --kubeconfig ~/.kube/prod-config cluster-info

# Test connectivity
make setup-prod
```

### Debugging Commands

```bash
# Check cluster status
kubectl --kubeconfig ~/.kube/kind-config get nodes

# View pods
kubectl --kubeconfig ~/.kube/kind-config get pods

# Check helm releases
helm list --kubeconfig ~/.kube/kind-config

# View logs
kubectl --kubeconfig ~/.kube/kind-config logs -l app=frontend
kubectl --kubeconfig ~/.kube/kind-config logs -l app=backend
```

## 🔄 Development Workflow

1. **Make code changes** in `/app/frontend` or `/app/backend`
2. **Build new images**:
   ```bash
   cd ../app && make build-all
   ```
3. **Reload into Kind**:
   ```bash
   make setup-dev
   ```
4. **Deploy updated application**:
   ```bash
   make install-dev
   ```

## 📊 Monitoring

### Grafana Access
- **Dev**: Port-forward or configure ingress
- **Prod**: Configure proper ingress with authentication
- **Default**: Admin credentials in values files

### InfluxDB Access
- **Dev**: `kubectl port-forward svc/influxdb2 8086:80`
- **Prod**: Configure secure ingress
- **API**: Available at `/api/v2/`

## 🤝 Contributing

1. Make changes in appropriate directories
2. Test in development environment first
3. Update documentation if needed
4. Test production deployment process

## 📝 Notes

- The Makefile automatically mounts NFS storage on first run
- Kind clusters persist between runs unless explicitly deleted
- Production deployments require manual kubeconfig setup
- All persistent data is stored on the NFS server

