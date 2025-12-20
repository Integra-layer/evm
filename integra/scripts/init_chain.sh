#!/bin/bash

# Integra Chain Initialization Script
# This script sets up a new Integra chain node for deployment

set -e

# Configuration
CHAIN_ID="${CHAIN_ID:-integra_1343-1}"
MONIKER="${MONIKER:-integra-node}"
KEYRING_BACKEND="${KEYRING_BACKEND:-test}"
DENOM="uintg"
DISPLAY_DENOM="INTG"
MIN_GAS_PRICE="0.0001${DENOM}"

# Paths
BINARY="intgd"
HOME_DIR="${HOME}/.integra"
CONFIG_DIR="${HOME_DIR}/config"
GENESIS="${CONFIG_DIR}/genesis.json"

echo "============================================"
echo "  Integra Chain Initialization"
echo "============================================"
echo "Chain ID: ${CHAIN_ID}"
echo "Moniker: ${MONIKER}"
echo "Home Directory: ${HOME_DIR}"
echo "Denom: ${DENOM}"
echo "============================================"

# Check if binary exists
if ! command -v ${BINARY} &> /dev/null; then
    echo "Error: ${BINARY} binary not found in PATH"
    echo "Please build and install with: cd integra && go install ./cmd/intgd"
    exit 1
fi

# Remove existing data (with confirmation)
if [ -d "${HOME_DIR}" ]; then
    read -p "Existing chain data found. Remove it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${HOME_DIR}"
    else
        echo "Aborting."
        exit 1
    fi
fi

# Initialize the chain
echo "Initializing chain..."
${BINARY} init ${MONIKER} --chain-id ${CHAIN_ID} --home ${HOME_DIR}

# Update genesis with correct denom
echo "Configuring genesis..."
cat ${GENESIS} | jq --arg denom "${DENOM}" '.app_state.staking.params.bond_denom = $denom' > ${GENESIS}.tmp && mv ${GENESIS}.tmp ${GENESIS}
cat ${GENESIS} | jq --arg denom "${DENOM}" '.app_state.crisis.constant_fee.denom = $denom' > ${GENESIS}.tmp && mv ${GENESIS}.tmp ${GENESIS}
cat ${GENESIS} | jq --arg denom "${DENOM}" '.app_state.gov.deposit_params.min_deposit[0].denom = $denom' > ${GENESIS}.tmp && mv ${GENESIS}.tmp ${GENESIS}
cat ${GENESIS} | jq --arg denom "${DENOM}" '.app_state.gov.params.min_deposit[0].denom = $denom' > ${GENESIS}.tmp && mv ${GENESIS}.tmp ${GENESIS}
cat ${GENESIS} | jq --arg denom "${DENOM}" '.app_state.mint.params.mint_denom = $denom' > ${GENESIS}.tmp && mv ${GENESIS}.tmp ${GENESIS}
cat ${GENESIS} | jq --arg denom "${DENOM}" '.app_state.evm.params.evm_denom = $denom' > ${GENESIS}.tmp && mv ${GENESIS}.tmp ${GENESIS}

# Set minimum gas prices in app.toml
sed -i.bak "s/minimum-gas-prices = \"\"/minimum-gas-prices = \"${MIN_GAS_PRICE}\"/" ${CONFIG_DIR}/app.toml

# Enable API and JSON-RPC
sed -i.bak 's/enable = false/enable = true/' ${CONFIG_DIR}/app.toml
sed -i.bak 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' ${CONFIG_DIR}/app.toml
sed -i.bak 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:1317"/' ${CONFIG_DIR}/app.toml

# Enable JSON-RPC
sed -i.bak 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/' ${CONFIG_DIR}/app.toml
sed -i.bak 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/' ${CONFIG_DIR}/app.toml

# Configure CometBFT for external access
sed -i.bak 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ${CONFIG_DIR}/config.toml
sed -i.bak 's/cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/' ${CONFIG_DIR}/config.toml

echo ""
echo "============================================"
echo "  Chain initialized successfully!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Create a validator key:"
echo "   ${BINARY} keys add validator --keyring-backend ${KEYRING_BACKEND}"
echo ""
echo "2. Add genesis account:"
echo "   ${BINARY} genesis add-genesis-account validator 100000000000${DENOM} --keyring-backend ${KEYRING_BACKEND}"
echo ""
echo "3. Create gentx:"
echo "   ${BINARY} genesis gentx validator 50000000000${DENOM} --chain-id ${CHAIN_ID} --keyring-backend ${KEYRING_BACKEND}"
echo ""
echo "4. Collect gentxs:"
echo "   ${BINARY} genesis collect-gentxs"
echo ""
echo "5. Start the node:"
echo "   ${BINARY} start"
echo ""
echo "Endpoints after start:"
echo "  - RPC: http://localhost:26657"
echo "  - REST API: http://localhost:1317"
echo "  - JSON-RPC (EVM): http://localhost:8545"
echo "  - WebSocket: ws://localhost:8546"

