#!/bin/bash
set -e

USER_NAME="${USER_NAME:-user}"

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

echo "Adding user ${USER_NAME} to docker group..."
usermod -aG docker "${USER_NAME}"

echo "Starting Docker service..."
service docker start

echo "Waiting for Docker to be ready..."
for _ in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! docker info >/dev/null 2>&1; then
    echo "Docker did not start within 120 seconds." >&2
    exit 1
fi

echo "Docker installed: $(docker --version)"
echo "Docker Compose: $(docker compose version)"