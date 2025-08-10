#!/user/bin/env bash

VERSION_FILE="VERSION.txt"
BASE_IMAGE="bitnami/nginx:1.29.0"
TAR_IMAGE="nginx.tar"
NFS_FOLDER="/nfs/export/images/"

APP_NAME="simple-frontend"

NFS_IP="10.0.0.137"
NFS_PATH="/export"
MOUNT_PATH="/nfs/export"
IMG_FOLDER="${MOUNT_PATH}/images"

if [ ! -f "$VERSION_FILE" ]; then
  echo "0.1.0" > "$VERSION_FILE"
fi

VERSION=$(cat "$VERSION_FILE")
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
echo "$NEW_VERSION" > "$VERSION_FILE"
echo "Bumping version to $NEW_VERSION"

# Remove old image from docker images
docker rm -f $(docker ps -a -q --filter ancestor=$APP_NAME) 2>/dev/null || true
docker rmi $APP_NAME:"$VERSION" 2>/dev/null || true


# Make sure BASE_IMAGE is available locally
if docker image inspect $BASE_IMAGE > /dev/null 2>&1; then
    echo "Base image $BASE_IMAGE found locally."
else
    echo "Base image $BASE_IMAGE not found locally. Checking NFS..."
    # Mount NFS if not already mounted
    if ! mountpoint -q "$MOUNT_PATH"; then
        sudo mount -t nfs "$NFS_IP:$NFS_PATH" "$MOUNT_PATH"
    fi

    if [ -f "${IMG_FOLDER}/${TAR_IMAGE}" ]; then
        echo "Loading base image from NFS..."
        docker load -i "${IMG_FOLDER}/${TAR_IMAGE}"
    else
        echo "Base image tarball not found on NFS. Pulling from Docker Hub..."
        docker pull $BASE_IMAGE
        # Save the pulled image to NFS for future use
        docker save -o "${IMG_FOLDER}/${TAR_IMAGE}" $BASE_IMAGE
    fi
fi

echo "Building Docker image for $APP_NAME:$NEW_VERSION ..."
docker build -t $APP_NAME:"$NEW_VERSION" -f Dockerfile .
echo "Docker image $APP_NAME:$NEW_VERSION built successfully."

# Update VERSION.txt with the new version
echo "$NEW_VERSION" > "$VERSION_FILE"