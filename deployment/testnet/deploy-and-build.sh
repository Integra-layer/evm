#!/bin/bash
# ============================================
# Script: deploy-and-build.sh
# Purpose: Upload source to nodes and build binary there
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."

# Testnet nodes
NODE1_IP="138.197.217.237"
NODE2_IP="64.227.86.117"
NODE3_IP="178.128.72.109"
SSH_USER="root"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   Deploy & Build on Testnet Nodes${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Create tarball of source (excluding heavy stuff)
echo -e "${YELLOW}[1/4] Creating source tarball...${NC}"
cd "${REPO_ROOT}"

# Create a clean tarball
tar --exclude='.git' \
    --exclude='node_modules' \
    --exclude='bin' \
    --exclude='build' \
    --exclude='*.tar.gz' \
    --exclude='data' \
    --exclude='.idea' \
    --exclude='.vscode' \
    -czf /tmp/integra-evm.tar.gz .

echo -e "${GREEN}  ✓ Tarball created: $(du -h /tmp/integra-evm.tar.gz | cut -f1)${NC}"

# Deploy to each node
for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo ""
    echo -e "${YELLOW}[2/4] Deploying to ${IP}...${NC}"
    
    # Install Go if not present
    echo "  → Checking Go installation..."
    ssh "${SSH_USER}@${IP}" "
        if ! command -v go &> /dev/null; then
            echo '    Installing Go...'
            wget -q https://go.dev/dl/go1.22.0.linux-amd64.tar.gz -O /tmp/go.tar.gz
            rm -rf /usr/local/go
            tar -C /usr/local -xzf /tmp/go.tar.gz
            echo 'export PATH=\$PATH:/usr/local/go/bin:/root/go/bin' >> /root/.bashrc
            export PATH=\$PATH:/usr/local/go/bin:/root/go/bin
        fi
        go version
    "
    
    # Upload source
    echo "  → Uploading source code..."
    scp /tmp/integra-evm.tar.gz "${SSH_USER}@${IP}:/tmp/"
    
    # Extract and build
    echo "  → Extracting and building..."
    ssh "${SSH_USER}@${IP}" "
        export PATH=\$PATH:/usr/local/go/bin:/root/go/bin
        
        # Clean and extract
        rm -rf /root/integra-evm
        mkdir -p /root/integra-evm
        cd /root/integra-evm
        tar -xzf /tmp/integra-evm.tar.gz
        
        # Build
        echo '    Building intgd...'
        cd integra
        go build -o /usr/local/bin/intgd ./cmd/intgd
        
        # Verify
        chmod +x /usr/local/bin/intgd
        /usr/local/bin/intgd version
    "
    
    echo -e "${GREEN}  ✓ Built on ${IP}${NC}"
done

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Build Complete on All Nodes!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Binary installed at /usr/local/bin/intgd on all nodes"
echo ""
echo "Next: Run setup-testnet.sh to initialize the network"
echo ""
