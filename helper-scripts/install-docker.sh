#!/bin/bash
# Docker installation script for Ubuntu/Debian and AlmaLinux/RHEL

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

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    echo "Error: Cannot detect OS. /etc/os-release not found."
    exit 1
fi

echo "Detected OS: $OS $OS_VERSION"
echo ""

# Function for Ubuntu/Debian
install_docker_ubuntu() {
    echo "Installing Docker for Ubuntu/Debian..."
    
    # Remove old versions if any
    echo "Removing old Docker versions..."
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update package index
    echo "Updating package index..."
    apt-get update
    
    # Install required packages
    echo "Installing required packages..."
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    echo "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "Adding Docker repository..."
    if [ "$OS" = "debian" ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Update package index again
    apt-get update
    
    # Install Docker Engine
    echo "Installing Docker Engine..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Function for AlmaLinux/RHEL/CentOS
install_docker_rhel() {
    echo "Installing Docker for AlmaLinux/RHEL/CentOS..."
    
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
}

# Install Docker based on OS
case "$OS" in
    ubuntu|debian)
        install_docker_ubuntu
        ;;
    almalinux|rhel|centos|rocky|fedora)
        install_docker_rhel
        ;;
    *)
        echo "Error: Unsupported OS: $OS"
        echo "This script supports Ubuntu, Debian, AlmaLinux, RHEL, CentOS, Rocky Linux, and Fedora"
        exit 1
        ;;
esac

# Reset any failed states
echo "Resetting any failed service states..."
systemctl reset-failed docker.socket docker.service 2>/dev/null || true

# Start and enable Docker socket first (required for socket activation)
echo "Starting Docker socket..."
systemctl start docker.socket
systemctl enable docker.socket

# Start and enable Docker service
echo "Starting Docker service..."
systemctl start docker.service
systemctl enable docker.service

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
