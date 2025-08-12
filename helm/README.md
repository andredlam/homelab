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

## 🌐 How to Access Your Services

The homelab deployment uses **ingress-nginx** to route traffic to your applications. All services are accessible through a single entry point.

### 🔧 Service Routes

| Service | URL Path | Destination | Port |
|---------|----------|-------------|------|
| **Frontend** | `http://homelab.local/` | React Application | 3000 |
| **Backend API** | `http://homelab.local/api` | FastAPI Backend | 8000 |
| **InfluxDB** | Port Forward Only | Time Series Database | 8086 |
| **Grafana** | Port Forward Only | Monitoring Dashboard | 3000 |

### 🏠 Method 1: Local Hostname (Recommended)

1. **Add to your hosts file**:
   ```bash
   # Linux/Mac: /etc/hosts
   # Windows: C:\Windows\System32\drivers\etc\hosts
   127.0.0.1 homelab.local
   ```

2. **Access your services**:
   ```bash
   # Frontend (React App)
   http://homelab.local:30080/
   
   # Backend API
   http://homelab.local:30080/api
   
   # API Documentation (if available)
   http://homelab.local:30080/api/docs
   ```

### 🔌 Method 2: Port Forwarding (Easy Testing)

1. **Forward ingress controller**:
   ```bash
   kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-ingress-nginx-controller 8080:80
   ```

2. **Access your services**:
   ```bash
   # Frontend
   http://localhost:8080/
   
   # Backend API  
   http://localhost:8080/api
   ```

3. **Forward specific services directly**:
   ```bash
   # Frontend only
   kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-frontend-service 3000:3000
   
   # Backend only
   kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-backend-service 8000:8000
   
   # InfluxDB
   kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-influxdb2 8086:80
   
   # Grafana (when available)
   kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-grafana 3000:3000
   ```

### 🖥️ Method 3: Direct Node Access

1. **Get Kind cluster node IP**:
   ```bash
   docker inspect kind-cluster-worker | grep IPAddress
   ```

2. **Access via NodePort**:
   ```bash
   # Replace <node-ip> with the actual IP address
   http://<node-ip>:30080/     # Frontend
   http://<node-ip>:30080/api  # Backend API
   ```

### 📊 Accessing Databases and Monitoring

#### **InfluxDB Access**
```bash
# Method 1: Port Forward
kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-influxdb2 8086:80

# Then access: http://localhost:8086
# Username: admin
# Password: admin123
# Token: dev-token-12345
# Organization: Scale-Sample
```

#### **Grafana Access (Monitoring Dashboard)**
```bash
# Method 1: Port Forward (Recommended)
kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-grafana 3000:3000

# Then access: http://localhost:3000
# Username: admin  
# Password: grafana123
# 
# Pre-configured with InfluxDB datasource:
# - Organization: Scale-Sample
# - Database: scale-sample
# - Token: dev-token-12345
```

**Note**: Grafana has a redirect loop issue when accessed via ingress subpath (`/grafana`). 
Use port forwarding for direct access until this is resolved.

### 🔧 Ingress Configuration Details

The ingress controller is configured with:

```yaml
# NodePort Service Ports
HTTP:  30080  # External access port
HTTPS: 30443  # HTTPS (when TLS configured)

# Internal Service Ports  
Frontend: 3000
Backend:  8000
InfluxDB: 8086 (via port-forward)
Grafana:  3000 (via port-forward)
```

### 🔒 HTTPS/TLS Configuration

For production deployments, you can enable HTTPS:

1. **Create TLS certificate**:
   ```bash
   kubectl create secret tls homelab-tls --cert=tls.crt --key=tls.key
   ```

2. **Update values.yaml**:
   ```yaml
   ingress:
     tls:
       - secretName: homelab-tls
         hosts:
           - homelab.local
   ```

3. **Access via HTTPS**:
   ```bash
   https://homelab.local:30443/
   ```

### ⚙️ Service Discovery

All services communicate internally using Kubernetes DNS:

```bash
# Internal service addresses
sample-dev-frontend-service.default.svc.cluster.local:3000
sample-dev-backend-service.default.svc.cluster.local:8000  
sample-dev-influxdb2.default.svc.cluster.local:80
```

This setup provides a complete development environment accessible through standard web URLs! 🚀

## � Monitoring with Grafana

### Accessing Grafana Dashboard

Grafana provides monitoring and visualization capabilities for your homelab deployment:

1. **Start port forwarding**:
   ```bash
   kubectl --kubeconfig ~/.kube/kind-config port-forward svc/sample-dev-grafana 3000:3000
   ```

2. **Open Grafana in browser**:
   ```
   http://localhost:3000
   ```

3. **Login credentials**:
   ```
   Username: admin
   Password: grafana123
   ```

### Pre-configured Datasources

Grafana comes pre-configured with InfluxDB integration:

- **InfluxDB Datasource**: Automatically configured
- **URL**: `http://sample-dev-influxdb2:8086`
- **Organization**: Scale-Sample
- **Database**: scale-sample
- **Token**: dev-token-12345

### Creating Your First Dashboard

1. **Navigate to Dashboards** → **Create** → **New Dashboard**
2. **Add a new panel**
3. **Select InfluxDB as the datasource**
4. **Use Flux query language** to query your data:
   ```flux
   from(bucket: "scale-sample")
     |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
     |> filter(fn: (r) => r["_measurement"] == "your_measurement")
   ```

### Alternative Access Methods

If port forwarding is not convenient:

```bash
# Method 2: NodePort exposure (requires service modification)
kubectl --kubeconfig ~/.kube/kind-config patch svc sample-dev-grafana -p '{"spec":{"type":"NodePort","ports":[{"port":3000,"nodePort":30030}]}}'

# Then access: http://homelab.local:30030
```

**Note**: The ingress route `/grafana` currently has redirect loop issues and is not recommended for access.

## �🔍 Troubleshooting

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

