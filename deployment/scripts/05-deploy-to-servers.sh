#!/bin/bash
# ============================================
# Script: 05-deploy-to-servers.sh
# Purpose: Deploy configuration and binary to servers
# Run: Execute on your LOCAL machine
# Requires: SSH access to all nodes
# ============================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/.."
source "${DEPLOY_DIR}/config.env"

OUTPUT_DIR="${DEPLOY_DIR}/generated"
BINARY_PATH="${DEPLOY_DIR}/../build/intgd"

# SSH user - modify if different
SSH_USER="${SSH_USER:-root}"

echo "============================================"
echo "Deploying Integra Network to Servers"
echo "============================================"
echo ""
echo "SSH User: ${SSH_USER}"
echo "Binary: ${BINARY_PATH}"
echo ""

# Check if binary exists
if [ ! -f "${BINARY_PATH}" ]; then
    echo "ERROR: Binary not found at ${BINARY_PATH}"
    echo ""
    echo "Please build the binary first:"
    echo "  cd /path/to/integra-evm"
    echo "  GOOS=linux GOARCH=amd64 make build"
    exit 1
fi

# Check if generated files exist
if [ ! -d "${OUTPUT_DIR}/node1" ]; then
    echo "ERROR: Generated files not found."
    echo "Please run 03-init-genesis.sh and 04-configure-nodes.sh first."
    exit 1
fi

deploy_to_node() {
    local NODE_NUM=$1
    local NODE_IP=$2
    local MONIKER=$3
    
    echo ""
    echo "--------------------------------------------"
    echo "Deploying to Node ${NODE_NUM}: ${MONIKER} (${NODE_IP})"
    echo "--------------------------------------------"
    
    local NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    local REMOTE_USER="${SSH_USER}"
    local REMOTE_HOST="${NODE_IP}"
    
    # Test SSH connection
    echo "[1/6] Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH OK'" 2>/dev/null; then
        echo "ERROR: Cannot connect to ${REMOTE_HOST} via SSH"
        echo "Please ensure:"
        echo "  1. SSH key is configured"
        echo "  2. Server is accessible"
        echo "  3. SSH_USER is correct (current: ${SSH_USER})"
        return 1
    fi
    
    # Create remote directories
    echo "[2/6] Creating remote directories..."
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p /root/${DAEMON_HOME}/config /root/${DAEMON_HOME}/data"
    
    # Copy binary
    echo "[3/6] Copying binary..."
    scp "${BINARY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}:/usr/local/bin/${BINARY_NAME}"
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "chmod +x /usr/local/bin/${BINARY_NAME}"
    
    # Copy configuration files
    echo "[4/6] Copying configuration files..."
    scp -r "${NODE_HOME}/config/"* "${REMOTE_USER}@${REMOTE_HOST}:/root/${DAEMON_HOME}/config/"
    
    # Copy keyring (for validator operations)
    echo "[5/6] Copying keyring..."
    if [ -d "${NODE_HOME}/keyring-test" ]; then
        scp -r "${NODE_HOME}/keyring-test" "${REMOTE_USER}@${REMOTE_HOST}:/root/${DAEMON_HOME}/"
    fi
    
    # Copy systemd service file
    echo "[6/6] Setting up systemd service..."
    scp "${DEPLOY_DIR}/systemd/intgd.service" "${REMOTE_USER}@${REMOTE_HOST}:/etc/systemd/system/"
    
    # Update service file with correct paths on remote
    ssh "${REMOTE_USER}@${REMOTE_HOST}" << 'REMOTE_EOF'
# Reload systemd
systemctl daemon-reload

# Enable service to start on boot
systemctl enable intgd

echo "Systemd service configured"
REMOTE_EOF
    
    echo "Node ${NODE_NUM} deployment complete!"
}

echo "[Step 1/2] Deploying to all nodes..."

deploy_to_node 1 "${NODE1_IP}" "${NODE1_MONIKER}"
deploy_to_node 2 "${NODE2_IP}" "${NODE2_MONIKER}"
deploy_to_node 3 "${NODE3_IP}" "${NODE3_MONIKER}"

echo ""
echo "============================================"
echo "Deployment Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo ""
echo "1. SSH into each server and start the nodes:"
echo "   ssh ${SSH_USER}@${NODE1_IP}"
echo "   systemctl start intgd"
echo ""
echo "2. Or start all nodes at once (run on each server):"
echo "   systemctl start intgd && journalctl -u intgd -f"
echo ""
echo "3. Check node status:"
echo "   systemctl status intgd"
echo "   ${BINARY_NAME} status --home /root/${DAEMON_HOME}"
echo ""
echo "4. View logs:"
echo "   journalctl -u intgd -f"
echo ""
echo "IMPORTANT: Start all nodes within a few minutes of each other"
echo "to ensure proper consensus initialization."
echo ""

