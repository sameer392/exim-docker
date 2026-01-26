#!/bin/bash
# Docker installation script for AlmaLinux/RHEL 9

set -e

echo "=========================================="
echo "Installing Docker and Docker Compose"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Remove old versions if any
echo "Removing old Docker versions..."
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true

# Install required packages
echo "Installing required packages..."
dnf install -y dnf-plugins-core

# Add Docker repository
echo "Adding Docker repository..."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine
echo "Installing Docker Engine..."
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
echo "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add current user to docker group (if not root)
if [ "$SUDO_USER" ]; then
    echo "Adding $SUDO_USER to docker group..."
    usermod -aG docker $SUDO_USER
fi

# Verify installation
echo ""
echo "Verifying Docker installation..."
docker --version
docker compose version

echo ""
echo "=========================================="
echo "Docker installation complete!"
echo "=========================================="
echo ""
echo "Docker is now installed and running."
echo ""
if [ "$SUDO_USER" ]; then
    echo "Note: User $SUDO_USER has been added to the docker group."
    echo "You may need to log out and back in for group changes to take effect."
    echo "Or run: newgrp docker"
fi
echo ""
echo "To test Docker, run: docker run hello-world"
echo ""
