#!/bin/bash
# ============================================
# Script: 04-configure-nodes.sh
# Purpose: Configure node settings (config.toml, app.toml)
# Run: Execute on your LOCAL machine after 03-init-genesis.sh
# ============================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/.."
source "${DEPLOY_DIR}/config.env"

OUTPUT_DIR="${DEPLOY_DIR}/generated"

echo "============================================"
echo "Configuring Integra Nodes"
echo "============================================"

# Get node IDs for persistent peers
get_node_id() {
    local NODE_NUM=$1
    local NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    ${BINARY_NAME} comet show-node-id --home "${NODE_HOME}"
}

echo ""
echo "[1/4] Getting node IDs..."

NODE1_ID=$(get_node_id 1)
NODE2_ID=$(get_node_id 2)
NODE3_ID=$(get_node_id 3)

echo "  Node 1 ID: ${NODE1_ID}"
echo "  Node 2 ID: ${NODE2_ID}"
echo "  Node 3 ID: ${NODE3_ID}"

# Build persistent peers string
PERSISTENT_PEERS="${NODE1_ID}@${NODE1_IP}:${P2P_PORT},${NODE2_ID}@${NODE2_IP}:${P2P_PORT},${NODE3_ID}@${NODE3_IP}:${P2P_PORT}"

echo ""
echo "Persistent peers: ${PERSISTENT_PEERS}"

echo ""
echo "[2/4] Configuring config.toml for each node..."

for NODE_NUM in 1 2 3; do
    NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    CONFIG_TOML="${NODE_HOME}/config/config.toml"
    eval NODE_IP="\${NODE${NODE_NUM}_IP}"
    eval MONIKER="\${NODE${NODE_NUM}_MONIKER}"
    
    echo "  Configuring node ${NODE_NUM} (${MONIKER})..."
    
    # Set moniker
    sed -i.bak "s/^moniker = .*/moniker = \"${MONIKER}\"/" "${CONFIG_TOML}"
    
    # Set external address for P2P
    sed -i.bak "s/^external_address = .*/external_address = \"${NODE_IP}:${P2P_PORT}\"/" "${CONFIG_TOML}"
    
    # Set persistent peers (exclude self)
    case ${NODE_NUM} in
        1) PEERS="${NODE2_ID}@${NODE2_IP}:${P2P_PORT},${NODE3_ID}@${NODE3_IP}:${P2P_PORT}" ;;
        2) PEERS="${NODE1_ID}@${NODE1_IP}:${P2P_PORT},${NODE3_ID}@${NODE3_IP}:${P2P_PORT}" ;;
        3) PEERS="${NODE1_ID}@${NODE1_IP}:${P2P_PORT},${NODE2_ID}@${NODE2_IP}:${P2P_PORT}" ;;
    esac
    sed -i.bak "s/^persistent_peers = .*/persistent_peers = \"${PEERS}\"/" "${CONFIG_TOML}"
    
    # Allow duplicate IPs (for testing/same network)
    sed -i.bak 's/^allow_duplicate_ip = .*/allow_duplicate_ip = true/' "${CONFIG_TOML}"
    
    # Set P2P listen address to listen on all interfaces
    sed -i.bak "s|^laddr = \"tcp://127.0.0.1:${P2P_PORT}\"|laddr = \"tcp://0.0.0.0:${P2P_PORT}\"|" "${CONFIG_TOML}"
    sed -i.bak 's|^laddr = "tcp://127.0.0.1:26656"|laddr = "tcp://0.0.0.0:26656"|' "${CONFIG_TOML}"
    
    # Set RPC listen address
    sed -i.bak "s|^laddr = \"tcp://127.0.0.1:${RPC_PORT}\"|laddr = \"tcp://0.0.0.0:${RPC_PORT}\"|" "${CONFIG_TOML}"
    sed -i.bak 's|^laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "${CONFIG_TOML}"
    
    # Enable prometheus metrics
    sed -i.bak 's/^prometheus = false/prometheus = true/' "${CONFIG_TOML}"
    
    # Consensus timeouts (production settings)
    sed -i.bak 's/^timeout_propose = .*/timeout_propose = "3s"/' "${CONFIG_TOML}"
    sed -i.bak 's/^timeout_prevote = .*/timeout_prevote = "1s"/' "${CONFIG_TOML}"
    sed -i.bak 's/^timeout_precommit = .*/timeout_precommit = "1s"/' "${CONFIG_TOML}"
    sed -i.bak 's/^timeout_commit = .*/timeout_commit = "3s"/' "${CONFIG_TOML}"
    
    # Clean up backup files
    rm -f "${CONFIG_TOML}.bak"
done

echo ""
echo "[3/4] Configuring app.toml for each node..."

for NODE_NUM in 1 2 3; do
    NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    APP_TOML="${NODE_HOME}/config/app.toml"
    
    echo "  Configuring node ${NODE_NUM}..."
    
    # Set minimum gas prices
    sed -i.bak "s/^minimum-gas-prices = .*/minimum-gas-prices = \"${MIN_GAS_PRICE}\"/" "${APP_TOML}"
    
    # Enable API
    sed -i.bak 's/^enable = false/enable = true/' "${APP_TOML}"
    
    # Set API address
    sed -i.bak "s|^address = \"tcp://localhost:1317\"|address = \"tcp://0.0.0.0:${API_PORT}\"|" "${APP_TOML}"
    sed -i.bak "s|^address = \"tcp://127.0.0.1:1317\"|address = \"tcp://0.0.0.0:${API_PORT}\"|" "${APP_TOML}"
    
    # Set gRPC address
    sed -i.bak "s|^address = \"localhost:9090\"|address = \"0.0.0.0:${GRPC_PORT}\"|" "${APP_TOML}"
    sed -i.bak "s|^address = \"0.0.0.0:9090\"|address = \"0.0.0.0:${GRPC_PORT}\"|" "${APP_TOML}"
    
    # Enable EVM JSON-RPC
    sed -i.bak 's/^enable-indexer = false/enable-indexer = true/' "${APP_TOML}"
    
    # Set pruning (default for validators)
    sed -i.bak 's/^pruning = .*/pruning = "default"/' "${APP_TOML}"
    
    # Enable telemetry
    sed -i.bak 's/^enabled = false/enabled = true/' "${APP_TOML}"
    
    # Clean up backup files
    rm -f "${APP_TOML}.bak"
done

echo ""
echo "[4/4] Creating EVM JSON-RPC configuration..."

# Create/update EVM config in app.toml for each node
for NODE_NUM in 1 2 3; do
    NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    APP_TOML="${NODE_HOME}/config/app.toml"
    
    # Check if EVM section exists, if not we'll need to handle it
    # The EVM config is typically added by the binary init command
    # But we ensure the key settings are correct
    
    if grep -q "\[evm\]" "${APP_TOML}"; then
        # Update EVM chain ID
        sed -i.bak "s/^evm-chain-id = .*/evm-chain-id = ${EVM_CHAIN_ID}/" "${APP_TOML}"
    fi
    
    if grep -q "\[json-rpc\]" "${APP_TOML}"; then
        # Enable JSON-RPC
        sed -i.bak '/\[json-rpc\]/,/^\[/{s/^enable = .*/enable = true/}' "${APP_TOML}"
        # Set JSON-RPC address
        sed -i.bak "s|^address = \"127.0.0.1:8545\"|address = \"0.0.0.0:${EVM_RPC_PORT}\"|" "${APP_TOML}"
        sed -i.bak "s|^ws-address = \"127.0.0.1:8546\"|ws-address = \"0.0.0.0:${EVM_WS_PORT}\"|" "${APP_TOML}"
        # Set API methods
        sed -i.bak 's/^api = .*/api = "eth,txpool,personal,net,debug,web3"/' "${APP_TOML}"
    fi
    
    rm -f "${APP_TOML}.bak"
done

# Save node info for deployment
NODE_INFO_FILE="${OUTPUT_DIR}/node_info.txt"
cat > "${NODE_INFO_FILE}" << EOF
============================================
INTEGRA NETWORK NODE INFORMATION
Generated: $(date)
============================================

Chain ID: ${CHAIN_ID}
EVM Chain ID: ${EVM_CHAIN_ID}

Persistent Peers:
${PERSISTENT_PEERS}

Node 1 (${NODE1_MONIKER}):
  IP: ${NODE1_IP}
  Node ID: ${NODE1_ID}
  P2P: ${NODE1_IP}:${P2P_PORT}
  RPC: http://${NODE1_IP}:${RPC_PORT}
  API: http://${NODE1_IP}:${API_PORT}
  EVM RPC: http://${NODE1_IP}:${EVM_RPC_PORT}
  EVM WS: ws://${NODE1_IP}:${EVM_WS_PORT}

Node 2 (${NODE2_MONIKER}):
  IP: ${NODE2_IP}
  Node ID: ${NODE2_ID}
  P2P: ${NODE2_IP}:${P2P_PORT}
  RPC: http://${NODE2_IP}:${RPC_PORT}
  API: http://${NODE2_IP}:${API_PORT}
  EVM RPC: http://${NODE2_IP}:${EVM_RPC_PORT}
  EVM WS: ws://${NODE2_IP}:${EVM_WS_PORT}

Node 3 (${NODE3_MONIKER}):
  IP: ${NODE3_IP}
  Node ID: ${NODE3_ID}
  P2P: ${NODE3_IP}:${P2P_PORT}
  RPC: http://${NODE3_IP}:${RPC_PORT}
  API: http://${NODE3_IP}:${API_PORT}
  EVM RPC: http://${NODE3_IP}:${EVM_RPC_PORT}
  EVM WS: ws://${NODE3_IP}:${EVM_WS_PORT}

============================================
EOF

echo ""
echo "============================================"
echo "Node Configuration Complete!"
echo "============================================"
echo ""
echo "Node information saved to: ${NODE_INFO_FILE}"
echo ""
echo "Next steps:"
echo "1. Build the binary for Linux: make build-linux"
echo "2. Run 05-deploy-to-servers.sh to deploy files"
echo ""

