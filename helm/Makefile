ENV ?= dev
ENV_PATH := ./environments/$(ENV)
VALUES_DIR ?= $(ENV_PATH)/values
TEMPLATE_DIR := $(ENV_PATH)/templates

export ENV 	# Export ENV for use in shell commands
export HOME	# Export HOME for use in shell commands


# ---------------------------------------------------------------------------
# Add this to the .bashrc so it will add kubeconfig automatically to kubectl
# ---------------------------------------------------------------------------
# export ENV=${ENV:-dev}
# function kubectl() {
#   if [[ "$ENV" == "dev" ]]; then
#     command kubectl --kubeconfig="$HOME/.kube/kind-config" "$@"
#   elif [[ "$ENV" == "prod" ]]; then
#     command kubectl --kubeconfig="$HOME/.kube/prod-config" "$@"
#   else
#     command kubectl "$@"
#   fi
# }
# ---------------------------------------------------------------------------


HELM_CHART_NAME := sample
HELM_CHART_PATH := ./sample
HELM_SUBCHART_PATH := $(HELM_CHART_PATH)/charts

# External NFS server configuration
NFS_IP := 10.0.0.137
NFS_PATH := /export
LOCAL_NFS_PATH := /nfs/export

# Cluster settings
ifeq ($(ENV),dev)
    CLUSTER_TYPE := kind
    CLUSTER_NAME := kind-cluster
    KUBECONFIG := $(HOME)/.kube/kind-config
else ifeq ($(ENV),prod)
    CLUSTER_TYPE := prod
    CLUSTER_NAME := prod-cluster
    KUBECONFIG := $(HOME)/.kube/prod-config
else
    $(error "Invalid ENV specified. Must be 'dev' or 'prod'")
endif

# Helm settings for each environment
HELM_RELEASE_NAME := $(HELM_CHART_NAME)-$(ENV)
HELM_NAMESPACE := default

# Mount NFS server to local path
ifeq ("$(wildcard $(LOCAL_NFS_PATH))", "")
	$(shell sudo mkdir -p $(LOCAL_NFS_PATH))
	$(shell sudo mount -t nfs $(NFS_IP):$(NFS_PATH) $(LOCAL_NFS_PATH))
endif

# Both dev and prod use the same NFS path
CHART_DIR := $(LOCAL_NFS_PATH)/helmcharts
CHART_FILES := $(wildcard $(CHART_DIR)/*.tgz)

.PHONY: untar-subcharts
define untar-subcharts
	@echo "Untarring subcharts in $(CHART_DIR)..."
	@for chart in $(CHART_FILES); do \
	    chart_name=$$(basename $$chart .tgz); \
		if [ -f $(HELM_SUBCHART_PATH)/$$chart_name ]; then \
			echo "Subchart $$chart_name already exists, skipping untar..."; \
		else \
			echo "Untarring $$chart..."; \
			tar -xzf $$chart -C $(HELM_SUBCHART_PATH); \
		fi; \
	done
endef

.PHONY: create-pv-pvc
define create-pv-pvc
	@echo "Creating PersistentVolume and PersistentVolumeClaim for NFS storage..."
	kubectl --kubeconfig=$(KUBECONFIG) apply -f $(TEMPLATE_DIR)/pv.yaml
	kubectl --kubeconfig=$(KUBECONFIG) apply -f $(TEMPLATE_DIR)/pvc.yaml
endef


define get-image-tag
	$(shell docker exec -t $(CLUSTER_NAME)-control-plane crictl images | grep $(1) | awk '{print $$2}' | tr -d '\r')
endef


define get-image-tags
	@echo "Getting image tags for frontend and backend..."
	$(eval FRONTEND_TAG := $(shell docker exec -t $(CLUSTER_NAME)-control-plane crictl images | grep frontend | awk '{print $$2}'))
	$(eval BACKEND_TAG := $(shell docker exec -t $(CLUSTER_NAME)-control-plane crictl images | grep backend | awk '{print $$2}'))
	@if [ -z "$(FRONTEND_TAG)" ] || [ -z "$(BACKEND_TAG)" ]; then \
		sleep 5; \
		$(eval FRONTEND_TAG := $(shell docker exec -t $(CLUSTER_NAME)-control-plane crictl images | grep frontend | awk '{print $$2}')) \
		$(eval BACKEND_TAG := $(shell docker exec -t $(CLUSTER_NAME)-control-plane crictl images | grep backend | awk '{print $$2}')) \
	fi
endef


IMAGE_DIR := $(LOCAL_NFS_PATH)/images
IMAGE_FILES := $(wildcard $(IMAGE_DIR)/*.tar)

# Update your load-images-from-tar function
.PHONY: load-images-from-tar
define load-images-from-tar
    @if [ -n "$(IMAGE_FILES)" ]; then \
        echo "Loading images from tar files..."; \
        for image_tar in $(IMAGE_FILES); do \
            image_name=$$(basename $$image_tar .tar); \
            echo "Processing $$image_name from $$image_tar..."; \
            if docker exec -t $(CLUSTER_NAME)-control-plane crictl images | grep $$image_name; then \
                echo "✓ Image $$image_name already loaded, skipping..."; \
            else \
                echo "→ Loading $$image_name into cluster..."; \
                kind load image-archive --name $(CLUSTER_NAME) $$image_tar; \
            fi; \
        done; \
    else \
        echo "No image tar files found in $(IMAGE_DIR). Skipping image load."; \
    fi
endef

.PHONY: create-kind-cluster
define create-kind-cluster
	kind create cluster --name $(CLUSTER_NAME) \
		--kubeconfig $(KUBECONFIG) \
		--config kind-config.yaml
endef

.PHONY: setup-prod-kubeconfig
define setup-prod-kubeconfig
	@echo "Setting up production kubeconfig..."
	@mkdir -p $(HOME)/.kube
	@if [ ! -f $(KUBECONFIG) ]; then \
		echo "❌ Production kubeconfig not found at $(KUBECONFIG)"; \
		echo "Please copy your production kubeconfig to $(KUBECONFIG)"; \
		echo "Example: kubectl config view --raw > $(KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "✅ Production kubeconfig found at $(KUBECONFIG)"
endef

.PHONY: check-kind-running
define check-kind-running
	@echo "Checking if Kind cluster $(CLUSTER_NAME) is running..."
	@mkdir -p $(HOME)/.kube
	@if ! kind get clusters | grep -q $(CLUSTER_NAME); then \
		echo "Creating KinD cluster $(CLUSTER_NAME)..."; \
		$(call create-kind-cluster); \
	else \
		echo "Kind cluster $(CLUSTER_NAME) is already running."; \
		echo "Updating kubeconfig file: $(KUBECONFIG)"; \
		kind export kubeconfig --name $(CLUSTER_NAME) --kubeconfig $(KUBECONFIG); \
	fi
endef

.PHONY: delete-kind-cluster
define delete-kind-cluster
	@echo "Deleting Kind cluster $(CLUSTER_NAME)..."
	@if kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind delete cluster --name $(CLUSTER_NAME); \
		rm -f $(KUBECONFIG); \
	else \
		echo "Kind cluster $(CLUSTER_NAME) does not exist."; \
	fi
endef

.PHONY: helm-uninstall
define helm-uninstall
	@echo "Cleaning up Helm release $(HELM_RELEASE_NAME) in namespace $(HELM_NAMESPACE)..."
	helm uninstall $(HELM_RELEASE_NAME) \
	    --namespace $(HELM_NAMESPACE) \
		--kubeconfig $(KUBECONFIG) || true
	kubectl delete namespace $(HELM_NAMESPACE) \
	 	--kubeconfig $(KUBECONFIG) || true
endef


# Main user-facing targets
.PHONY: setup-dev setup-prod install-dev install-prod clean-dev clean-prod init-prod
setup-dev:
	@$(MAKE) setup ENV=dev

setup-prod:
	@$(MAKE) setup ENV=prod

install-dev:
	@$(MAKE) install ENV=dev

install-prod:
	@$(MAKE) install ENV=prod

clean-dev:
	@$(MAKE) clean ENV=dev

clean-prod:
	@$(MAKE) clean ENV=prod

# Initialize production environment (one-time setup)
init-prod:
	@echo ">>> Initializing production environment..."
	@mkdir -p $(HOME)/.kube
	@echo "Please ensure you have:"
	@echo "1. Access to your production Kubernetes cluster"
	@echo "2. kubectl configured for production"
	@echo "3. Run: kubectl config view --raw > $(HOME)/.kube/prod-config"
	@echo "Then run: make setup-prod"

# PV-PVC must be deployed for influxdb to work
.PHONY: setup
setup:
	@echo ">>> Initializing $(ENV) environment..."
	@echo "Cluster Type: $(CLUSTER_TYPE)"
	@echo "Cluster Name: $(CLUSTER_NAME)"
	@echo "Kubeconfig: $(KUBECONFIG)"
	@$(MAKE) setup-cluster-$(CLUSTER_TYPE)
	@echo "Creating PV and PVC resources..."
	$(call create-pv-pvc)

.PHONY: setup-cluster-kind
setup-cluster-kind:
	@echo "Setting up Kind cluster for development..."
	$(call untar-subcharts)
	$(call check-kind-running)
	$(call load-images-from-tar)

.PHONY: setup-cluster-prod
setup-cluster-prod:
	@echo "Setting up production cluster..."
	$(call setup-prod-kubeconfig)
	@echo "Checking production cluster connectivity..."
	@kubectl --kubeconfig=$(KUBECONFIG) cluster-info || (echo "❌ Cannot connect to production cluster. Please check $(KUBECONFIG)" && exit 1)
	$(call untar-subcharts)

# docker exec -it kind-cluster-control-plane crictl images

.PHONY: install
install:
	$(eval fe_tag := $(call get-image-tag,simple-frontend))
	@if [ -z "$(fe_tag)" ]; then \
		echo "Error: simple-frontend image not found in cluster $(CLUSTER_NAME)"; \
		exit 1; \
	fi
	@echo "Using frontend image tag: $(fe_tag)"

	$(eval be_tag := $(call get-image-tag,simple-backend))
	@if [ -z "$(be_tag)" ]; then \
		echo "Error: simple-backend image not found in cluster $(CLUSTER_NAME)"; \
		exit 1; \
	fi
	@echo "Using backend image tag: $(be_tag)"

	# Update helm dependencies
	helm dep update $(HELM_CHART_PATH)
	# Install helm chart with image tags
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_PATH) \
		--namespace $(HELM_NAMESPACE) \
		--create-namespace \
		--kubeconfig $(KUBECONFIG) \
		--set frontend.image.tag=$(fe_tag) \
		--set backend.image.tag=$(be_tag) \
		-f $(VALUES_DIR)/values.yaml --debug


.PHONY: uninstall
uninstall:
	$(call helm-uninstall)


.PHONY: clean
clean:
	$(call helm-uninstall)
	$(call delete-kind-cluster)
