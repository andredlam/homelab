#!/bin/bash

# # Download ubuntu image if not existed
if [ ! -f "../ansible/roles/kvm/files/jammy-server-cloudimg-amd64.img" ]; then
    wget -nc https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -P ../ansible/roles/kvm/files/
fi

wget -nc https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/containerd.io_1.6.22-1_amd64.deb -P ../ansible/roles/vms/files/
wget -nc https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce_24.0.6-1~ubuntu.22.04~jammy_amd64.deb -P ../ansible/roles/vms/files/
wget -nc https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce-cli_24.0.6-1~ubuntu.22.04~jammy_amd64.deb -P ../ansible/roles/vms/files/
wget -nc https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-buildx-plugin_0.11.2-1~ubuntu.22.04~jammy_amd64.deb -P ../ansible/roles/vms/files/
wget -nc https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-compose-plugin_2.21.0-1~ubuntu.22.04~jammy_amd64.deb -P ../ansible/roles/vms/files/

# Use "docker search" to find the latest version of the image
# docker search ubuntu:22.04
# docker search ubuntu:jammy
# docker search ubuntu:latest


if ! docker image inspect grafana/grafana  >/dev/null 2>&1; then
    echo "Image not found locally. Pulling grafana ..."
    docker pull grafana/grafana
    docker save --output ../ansible/roles/vms/files/grafana.tar grafana/grafana
else
    echo "Grafana image already exists locally."
fi

if ! docker image inspect prom/prometheus  >/dev/null 2>&1; then
    echo "Image not found locally. Pulling prometheus ..."
    docker pull prom/prometheus
    docker save --output ../ansible/roles/vms/files/prometheus.tar prom/prometheus
else
    echo "Prometheus image already exists locally."
fi

if ! docker image inspect prom/blackbox-exporter  >/dev/null 2>&1; then
    echo "Image not found locally. Pulling blackbox-exporter ..."
    docker pull prom/blackbox-exporter
    docker save --output ../ansible/roles/vms/files/blackbox.tar prom/blackbox-exporter
else
    echo "Blackbox-exporter image already exists locally."
fi

if ! docker image inspect prom/node-exporter  >/dev/null 2>&1; then
    echo "Image not found locally. Pulling node-exporter ..."
    docker pull prom/node-exporter
    docker save --output ../ansible/roles/vms/files/node-exporter.tar prom/node-exporter
else
    echo "Node-exporter image already exists locally."
fi

if ! docker image inspect bitnami/redis-exporter  >/dev/null 2>&1; then
    echo "Image not found locally. Pulling redis-exporter ..."
    docker pull bitnami/redis-exporter
    docker save --output ../ansible/roles/vms/files/redis-exporter.tar bitnami/redis-exporter
else
    echo "Redis-exporter image already exists locally."
fi

if ! docker image inspect bitnami/postgres-exporter  >/dev/null 2>&1; then
    echo "Image not found locally. Pulling postgres-exporter ..."
    docker pull bitnami/postgres-exporter
    docker save --output ../ansible/roles/vms/files/postgres-exporter.tar bitnami/postgres-exporter
else
    echo "Postgres-exporter image already exists locally."
fi

