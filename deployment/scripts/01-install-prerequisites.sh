#!/bin/bash
# ============================================
# Script: 01-install-prerequisites.sh
# Purpose: Install required dependencies on Ubuntu server
# Run: Execute on each node as root
# ============================================

set -e

echo "============================================"
echo "Installing Prerequisites for Integra Node"
echo "============================================"

# Update system
echo "[1/6] Updating system packages..."
apt-get update && apt-get upgrade -y

# Install essential packages
echo "[2/6] Installing essential packages..."
apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    jq \
    make \
    gcc \
    g++ \
    lz4 \
    unzip \
    aria2 \
    ufw \
    fail2ban \
    htop \
    tmux \
    nano \
    vim

# Install Go (required version 1.22+)
echo "[3/6] Installing Go 1.22..."
GO_VERSION="1.22.5"
wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
rm "go${GO_VERSION}.linux-amd64.tar.gz"

# Set up Go environment
echo "[4/6] Configuring Go environment..."
cat >> /etc/profile.d/go.sh << 'EOF'
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF

source /etc/profile.d/go.sh

# Verify Go installation
echo "[5/6] Verifying Go installation..."
go version

# Create integra user (non-root)
echo "[6/6] Creating integra user..."
if ! id "integra" &>/dev/null; then
    useradd -m -s /bin/bash integra
    echo "integra ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/integra
    echo "User 'integra' created successfully"
else
    echo "User 'integra' already exists"
fi

# Set up Go for integra user
su - integra -c 'cat >> ~/.bashrc << EOF
export GOROOT=/usr/local/go
export GOPATH=\$HOME/go
export GO111MODULE=on
export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin
EOF'

echo ""
echo "============================================"
echo "Prerequisites installed successfully!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Copy the intgd binary to /usr/local/bin/"
echo "2. Run 02-setup-firewall.sh"
echo ""

