#!/bin/bash
# ============================================
# Script: quick-deploy.sh
# Purpose: One-click deployment of Integra Network
# Run: Execute on your LOCAL machine with SSH access to servers
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "Integra Network Quick Deployment"
echo "============================================"
echo ""
echo "This script will:"
echo "  1. Build the binary for Linux"
echo "  2. Initialize genesis and validator keys"
echo "  3. Configure all nodes"
echo "  4. Deploy to servers"
echo "  5. Start the network"
echo ""
echo "Prerequisites:"
echo "  - SSH access to all 3 servers"
echo "  - Go 1.22+ installed locally"
echo "  - Servers are fresh Ubuntu installations"
echo ""

read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo ""
echo "Step 1: Building binary..."
echo "--------------------------------------------"
"${SCRIPT_DIR}/build-binary.sh"

echo ""
echo "Step 2: Initializing genesis and keys..."
echo "--------------------------------------------"
"${SCRIPT_DIR}/03-init-genesis.sh"

echo ""
echo "Step 3: Configuring nodes..."
echo "--------------------------------------------"
"${SCRIPT_DIR}/04-configure-nodes.sh"

echo ""
echo "Step 4: Deploying to servers..."
echo "--------------------------------------------"
"${SCRIPT_DIR}/05-deploy-to-servers.sh"

echo ""
echo "Step 5: Starting network..."
echo "--------------------------------------------"
"${SCRIPT_DIR}/06-start-network.sh"

echo ""
echo "============================================"
echo "DEPLOYMENT COMPLETE!"
echo "============================================"
echo ""
echo "Your Integra Network is now running!"
echo ""
echo "IMPORTANT: Secure your validator mnemonics:"
echo "  ${SCRIPT_DIR}/../generated/validator_mnemonics.txt"
echo ""

