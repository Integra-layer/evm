#!/bin/bash
# ============================================
# Script: 06-start-network.sh
# Purpose: Start all nodes in the network
# Run: Execute on your LOCAL machine
# Requires: SSH access to all nodes
# ============================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/.."
source "${DEPLOY_DIR}/config.env"

SSH_USER="${SSH_USER:-root}"

echo "============================================"
echo "Starting Integra Network"
echo "============================================"
echo ""

start_node() {
    local NODE_IP=$1
    local MONIKER=$2
    
    echo "Starting ${MONIKER} at ${NODE_IP}..."
    
    ssh "${SSH_USER}@${NODE_IP}" << 'REMOTE_EOF'
# Stop if running
systemctl stop intgd 2>/dev/null || true

# Start the node
systemctl start intgd

# Wait a moment
sleep 2

# Check status
if systemctl is-active --quiet intgd; then
    echo "Node started successfully!"
else
    echo "ERROR: Node failed to start"
    journalctl -u intgd -n 20 --no-pager
    exit 1
fi
REMOTE_EOF
}

echo "[1/3] Starting Node 1 (${NODE1_MONIKER})..."
start_node "${NODE1_IP}" "${NODE1_MONIKER}"

echo ""
echo "[2/3] Starting Node 2 (${NODE2_MONIKER})..."
start_node "${NODE2_IP}" "${NODE2_MONIKER}"

echo ""
echo "[3/3] Starting Node 3 (${NODE3_MONIKER})..."
start_node "${NODE3_IP}" "${NODE3_MONIKER}"

echo ""
echo "============================================"
echo "All Nodes Started!"
echo "============================================"
echo ""
echo "Waiting 10 seconds for nodes to connect..."
sleep 10

echo ""
echo "Checking network status..."
echo ""

check_node_status() {
    local NODE_IP=$1
    local MONIKER=$2
    
    echo "--- ${MONIKER} (${NODE_IP}) ---"
    
    # Check if RPC is responding
    if curl -s "http://${NODE_IP}:${RPC_PORT}/status" > /dev/null 2>&1; then
        local STATUS=$(curl -s "http://${NODE_IP}:${RPC_PORT}/status")
        local LATEST_HEIGHT=$(echo "${STATUS}" | jq -r '.result.sync_info.latest_block_height')
        local CATCHING_UP=$(echo "${STATUS}" | jq -r '.result.sync_info.catching_up')
        local VOTING_POWER=$(echo "${STATUS}" | jq -r '.result.validator_info.voting_power')
        
        echo "  Status: Online"
        echo "  Latest Block: ${LATEST_HEIGHT}"
        echo "  Catching Up: ${CATCHING_UP}"
        echo "  Voting Power: ${VOTING_POWER}"
    else
        echo "  Status: RPC not responding (node may still be starting)"
    fi
    echo ""
}

check_node_status "${NODE1_IP}" "${NODE1_MONIKER}"
check_node_status "${NODE2_IP}" "${NODE2_MONIKER}"
check_node_status "${NODE3_IP}" "${NODE3_MONIKER}"

echo "============================================"
echo "Network Endpoints"
echo "============================================"
echo ""
echo "RPC Endpoints:"
echo "  http://${NODE1_IP}:${RPC_PORT}"
echo "  http://${NODE2_IP}:${RPC_PORT}"
echo "  http://${NODE3_IP}:${RPC_PORT}"
echo ""
echo "EVM JSON-RPC Endpoints (for MetaMask):"
echo "  http://${NODE1_IP}:${EVM_RPC_PORT}"
echo "  http://${NODE2_IP}:${EVM_RPC_PORT}"
echo "  http://${NODE3_IP}:${EVM_RPC_PORT}"
echo ""
echo "REST API Endpoints:"
echo "  http://${NODE1_IP}:${API_PORT}"
echo "  http://${NODE2_IP}:${API_PORT}"
echo "  http://${NODE3_IP}:${API_PORT}"
echo ""
echo "============================================"
echo "MetaMask Configuration"
echo "============================================"
echo ""
echo "Network Name: Integra Network"
echo "RPC URL: http://${NODE1_IP}:${EVM_RPC_PORT}"
echo "Chain ID: ${EVM_CHAIN_ID}"
echo "Currency Symbol: ${TOKEN_SYMBOL}"
echo "Block Explorer: (none configured)"
echo ""

