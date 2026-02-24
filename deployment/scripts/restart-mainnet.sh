#!/bin/bash
# ============================================
# Script: restart-mainnet.sh
# Purpose: Reset and restart mainnet with new genesis
# WARNING: This WIPES ALL DATA and restarts from block 0
# ============================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/.."
source "${DEPLOY_DIR}/config.env"

SSH_USER="${SSH_USER:-root}"
GENESIS_FILE="${DEPLOY_DIR}/mainnet/genesis.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${RED}============================================${NC}"
echo -e "${RED}⚠️  MAINNET GENESIS RESET - DESTRUCTIVE  ⚠️${NC}"
echo -e "${RED}============================================${NC}"
echo ""
echo "This script will:"
echo "  1. STOP all 3 validator nodes"
echo "  2. WIPE all blockchain data"
echo "  3. Deploy new genesis.json"
echo "  4. RESTART all nodes from block 0"
echo ""
echo "Nodes to reset:"
echo "  - Node 1: ${NODE1_IP} (${NODE1_MONIKER})"
echo "  - Node 2: ${NODE2_IP} (${NODE2_MONIKER})"
echo "  - Node 3: ${NODE3_IP} (${NODE3_MONIKER})"
echo ""
echo "Genesis file: ${GENESIS_FILE}"
echo ""

# Check genesis file exists
if [ ! -f "${GENESIS_FILE}" ]; then
    echo -e "${RED}ERROR: Genesis file not found at ${GENESIS_FILE}${NC}"
    exit 1
fi

# Confirmation
read -p "Are you SURE you want to WIPE ALL DATA and restart? (type 'YES' to confirm): " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${YELLOW}Starting mainnet reset...${NC}"
echo ""

# Function to reset a single node
reset_node() {
    local NODE_IP=$1
    local MONIKER=$2
    local NODE_NUM=$3
    
    echo ""
    echo "============================================"
    echo -e "${YELLOW}[${NODE_NUM}/3] Resetting ${MONIKER} (${NODE_IP})${NC}"
    echo "============================================"
    
    # Step 1: Stop the node
    echo "  → Stopping node..."
    ssh "${SSH_USER}@${NODE_IP}" "systemctl stop intgd 2>/dev/null || true"
    sleep 2
    
    # Step 2: Reset chain data
    echo "  → Resetting blockchain data..."
    ssh "${SSH_USER}@${NODE_IP}" "intgd comet unsafe-reset-all --home /root/.intgd --keep-addr-book"
    
    # Step 3: Copy new genesis
    echo "  → Deploying new genesis.json..."
    scp "${GENESIS_FILE}" "${SSH_USER}@${NODE_IP}:/root/.intgd/config/genesis.json"
    
    # Step 4: Verify genesis was copied
    echo "  → Verifying genesis..."
    local REMOTE_CHAIN_ID=$(ssh "${SSH_USER}@${NODE_IP}" "cat /root/.intgd/config/genesis.json | jq -r '.chain_id'")
    if [ "$REMOTE_CHAIN_ID" != "${CHAIN_ID}" ]; then
        echo -e "${RED}  ✗ ERROR: Chain ID mismatch! Expected ${CHAIN_ID}, got ${REMOTE_CHAIN_ID}${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✓ Genesis verified (chain_id: ${REMOTE_CHAIN_ID})${NC}"
}

# Reset all nodes (but don't start yet)
reset_node "${NODE1_IP}" "${NODE1_MONIKER}" "1"
reset_node "${NODE2_IP}" "${NODE2_MONIKER}" "2"
reset_node "${NODE3_IP}" "${NODE3_MONIKER}" "3"

echo ""
echo "============================================"
echo -e "${YELLOW}Starting all nodes...${NC}"
echo "============================================"

# Start all nodes
start_node() {
    local NODE_IP=$1
    local MONIKER=$2
    
    echo "  → Starting ${MONIKER}..."
    ssh "${SSH_USER}@${NODE_IP}" "systemctl start intgd"
}

start_node "${NODE1_IP}" "${NODE1_MONIKER}"
sleep 3
start_node "${NODE2_IP}" "${NODE2_MONIKER}"
sleep 3
start_node "${NODE3_IP}" "${NODE3_MONIKER}"

echo ""
echo "Waiting 15 seconds for nodes to connect and produce blocks..."
sleep 15

echo ""
echo "============================================"
echo -e "${GREEN}Checking Network Status${NC}"
echo "============================================"

check_node() {
    local NODE_IP=$1
    local MONIKER=$2
    
    echo ""
    echo "--- ${MONIKER} (${NODE_IP}) ---"
    
    if curl -s "http://${NODE_IP}:${RPC_PORT}/status" > /dev/null 2>&1; then
        local STATUS=$(curl -s "http://${NODE_IP}:${RPC_PORT}/status")
        local LATEST_HEIGHT=$(echo "${STATUS}" | jq -r '.result.sync_info.latest_block_height')
        local CATCHING_UP=$(echo "${STATUS}" | jq -r '.result.sync_info.catching_up')
        local VOTING_POWER=$(echo "${STATUS}" | jq -r '.result.validator_info.voting_power')
        local NODE_ID=$(echo "${STATUS}" | jq -r '.result.node_info.id')
        
        echo -e "  Status:       ${GREEN}✓ Online${NC}"
        echo "  Node ID:      ${NODE_ID}"
        echo "  Block Height: ${LATEST_HEIGHT}"
        echo "  Catching Up:  ${CATCHING_UP}"
        echo "  Voting Power: ${VOTING_POWER}"
    else
        echo -e "  Status: ${RED}✗ RPC not responding${NC}"
        echo "  Checking logs..."
        ssh "${SSH_USER}@${NODE_IP}" "journalctl -u intgd -n 10 --no-pager" 2>/dev/null || true
    fi
}

check_node "${NODE1_IP}" "${NODE1_MONIKER}"
check_node "${NODE2_IP}" "${NODE2_MONIKER}"
check_node "${NODE3_IP}" "${NODE3_MONIKER}"

echo ""
echo "============================================"
echo -e "${GREEN}✓ MAINNET RESET COMPLETE!${NC}"
echo "============================================"
echo ""
echo "Network Endpoints:"
echo "  Tendermint RPC: http://${NODE1_IP}:${RPC_PORT}"
echo "  EVM JSON-RPC:   http://${NODE1_IP}:${EVM_RPC_PORT}"
echo "  REST API:       http://${NODE1_IP}:${API_PORT}"
echo ""
echo "Genesis Configuration:"
echo "  Chain ID:     ${CHAIN_ID}"
echo "  EVM Chain ID: ${EVM_CHAIN_ID}"
echo "  Token:        ${TOKEN_SYMBOL} (${BASE_DENOM})"
echo ""
