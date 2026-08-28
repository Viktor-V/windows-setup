#!/bin/bash
set -e

echo "Setting up Portainer..."
docker volume inspect portainer_data >/dev/null 2>&1 || docker volume create portainer_data

if ! docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    echo "Creating Portainer container..."
    docker run -d \
        --name portainer \
        --restart always \
        -p 9000:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
    echo "Portainer container created"
else
    echo "Portainer container already exists, starting it..."
    docker start portainer 2>/dev/null || true
fi

echo "Portainer is running on http://localhost:9000"