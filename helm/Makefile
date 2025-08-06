ENV ?= dev
ENV_PATH := ./environments/$(ENV)
VALUES_FILE ?= $(ENV_PATH)/values/values.yaml

HELM_CHART_NAME := sample
HELM_CHART_PATH := ./sample
HELM_SUBCHART_PATH := $(HELM_CHART_PATH)/charts

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
HELM_NAMESPACE := $(HELM_CHART_NAME)-$(ENV)

# External NFS server configuration
NFS_IP := 10.0.0.100
NFS_PATH := /export
LOCAL_NFS_PATH := /nfs/export

# Mount NFS server to local path
ifeq ("$(wildcard $(LOCAL_NFS_PATH))", "")
	$(shell sudo mkdir -p $(LOCAL_NFS_PATH))
	$(shell sudo mount -t nfs $(NFS_IP):$(NFS_PATH) $(LOCAL_NFS_PATH))
endif

# Both dev and prod use the same NFS path
CHART_DIR := $(LOCAL_NFS_PATH)/charts
CHART_FILES := $(wildcard $(CHART_DIR)/*.tgz)
IMAGE_DIR := $(LOCAL_NFS_PATH)/images
IMAGE_FILES := $(wildcard $(IMAGE_DIR)/*.tar)


.PHONY: untar-subcharts
define untar-subcharts
	@echo "Checking for subcharts in $(CHART_DIR)..."
	@for chart in $(CHART_FILES); do \
	    chart_name = $(shell basename $$chart .tgz); \
		if [ -f $(HELM_SUBCHART_PATH)/$$chart_name ]; then \
			echo "Subchart $$chart_name already exists, skipping untar..."; \
		else \
			echo "Untarring $$chart..."; \
			tar -xzf $$chart -C $(HELM_SUBCHART_PATH); \
		fi; \
	done
endef

define get-image-tag
	@echo "Extracting image tag for image: $(1)..."
	$(eval TAG := $(shell docker exec -t $(CLUSTER_NAME)-control-plane crictl images | grep $(1) | awk '{print $$2}'))
	@if [ -z "$(TAG)" ]; then \
		echo "Error: Image $(1) not found in cluster $(CLUSTER_NAME)."; \
		exit 1; \
	else \
		echo "Image tag for $(1) is: $(TAG)"; \
		echo $(TAG); \
	fi
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

# OS detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	OS := mac
	INSTALL_CMD := brew install
else ifeq ($(UNAME_S),Linux)
	OS := linux
	INSTALL_CMD := sudo apt-get install -y
endif

.PHONY: create-kind-cluster
define create-kind-cluster
	kind create cluster --name $(KIND_CLUSTER_NAME) \
		--kubeconfig $(KUBECONFIG) \
		--config kind-config.yaml
endef

.PHONY: check-kind-running
define check-kind-running
	@echo "Checking if Kind cluster $(KIND_CLUSTER_NAME) is running..."
	@if ! kind get clusters | grep -q $(KIND_CLUSTER_NAME); then \
		echo "Creating KinD cluster $(KIND_CLUSTER_NAME)..."; \
		$(call create-kind-cluster); \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) is already running."; \
	fi
endef

.PHONY: delete-kind-cluster
define delete-kind-cluster
	@echo "Deleting Kind cluster $(KIND_CLUSTER_NAME)..."
	@if kind get clusters | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		kind delete cluster --name $(KIND_CLUSTER_NAME); \
		rm -f $(KUBECONFIG); \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) does not exist."; \
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
.PHONY: install-dev install-prod clean-dev clean-prod
install-dev:
    @$(MAKE) install ENV=dev

install-prod:
    @$(MAKE) install ENV=prod

clean-dev:
    @$(MAKE) clean ENV=dev

clean-prod:
    @$(MAKE) clean ENV=prod

.PHONY: setup-cluster
setup-cluster:
	@echo ">>> Setting up cluster for $(ENV) environment..."
    @if [ "$(ENV)" = "dev" ]; then \
        $(call check-kind-running); \
        $(call load-images-from-tar); \
    else \
        echo "Checking access to production cluster..."; \
        kubectl --kubeconfig=$(KUBECONFIG) get nodes || \
        (echo "ERROR: Cannot access production cluster. Check KUBECONFIG." && exit 1); \
    fi

.PHONY: install
install: setup-cluster
	@echo ">>> Deploying Helm chart $(HELM_CHART_NAME) for $(ENV) environment..."
	$(call untar-subcharts)

	tag = $(shell $(call get-image-tag,frontend))
	@echo "Using image tag: $(tag)"

	helm dep update $(HELM_CHART_PATH)
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_PATH) \
		--namespace $(HELM_NAMESPACE) \
		--create-namespace \
		--kubeconfig $(KUBECONFIG) \
		-f $(VALUES_FILE) \
		--set nfs-subdir-external-provisioner.nfs.server=$(NFS_IP) \
		--set nfs-subdir-external-provisioner.nfs.path=$(NFS_PATH); \

.PHONY: uninstall
clean:
	$(call helm-uninstall)

.PHONY: clean
clean:
	$(call helm-uninstall)
	$(call delete-kind-cluster)

.PHONY: upgrade
upgrade:
    @echo ">>> Upgrading $(ENV) environment..."
    @if [ "$(ENV)" = "dev" ]; then \
        $(call check-kind-running); \
    fi
    helm upgrade $(HELM_RELEASE_NAME) $(HELM_CHART_PATH) \
        --namespace $(HELM_NAMESPACE) \
        --kubeconfig $(KUBECONFIG) \
        -f $(VALUES_FILE)


# # Development workflow
# make install-dev     # Creates KinD, loads images, deploys
# make clean-dev       # Uninstalls from KinD
# make cleanall-dev    # Uninstalls and deletes KinD cluster

# # Production workflow  
# make install-prod    # Deploys to production cluster
# make clean-prod      # Uninstalls from production

# # Check what's running
# kubectl --kubeconfig .kubeconfig-dev get pods     # Dev
# kubectl --kubeconfig ~/.kube/prod-config get pods # Prod