#!/bin/bash
set -e

echo "Setting up Docker repository..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Installing Docker packages..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Adding user viktorv to docker group..."
usermod -aG docker viktorv

echo "Starting Docker service..."
service docker start

echo "Waiting for Docker to be ready..."
until docker info >/dev/null 2>&1; do
    sleep 2
done

echo "Docker installed: $(docker --version)"
echo "Docker Compose: $(docker compose version)"