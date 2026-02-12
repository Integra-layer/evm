#!/bin/bash
# ============================================
# Script: setup-testnet.sh
# Purpose: Full testnet setup with 3 validators
# Network: Ormos Testnet (ormos-1)
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   Ormos Testnet Setup${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Configuration
VALIDATOR_STAKE="1000000000000000000000000000"  # 1 Billion IRL
TREASURY_BALANCE="99000000000000000000000000000"  # 99 Billion IRL
FAUCET_BALANCE="1000000000000000000000000000"     # 1 Billion IRL

# Binary path (from integra-evm repo)
REPO_ROOT="${SCRIPT_DIR}/../.."
BINARY_PATH="${REPO_ROOT}/bin/intgd"

echo "Configuration:"
echo "  Chain ID:        ${CHAIN_ID}"
echo "  EVM Chain ID:    ${EVM_CHAIN_ID}"
echo "  Token:           ${TOKEN_SYMBOL} (${BASE_DENOM})"
echo ""
echo "Nodes:"
echo "  Node 1: ${NODE1_IP}"
echo "  Node 2: ${NODE2_IP}"
echo "  Node 3: ${NODE3_IP}"
echo ""
echo "Allocation:"
echo "  Treasury:   99,000,000,000 oIRL"
echo "  Faucet:      1,000,000,000 oIRL"
echo "  Validators:  3,000,000,000 oIRL (1B each)"
echo "  Total:     103,000,000,000 oIRL"
echo ""

read -p "Continue with testnet setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# ============================================
# STEP 1: Build Binary
# ============================================
echo ""
echo -e "${YELLOW}[1/8] Building intgd binary...${NC}"

cd "${REPO_ROOT}"
if [ ! -f "${BINARY_PATH}" ]; then
    echo "  → Building from source..."
    make build
else
    echo "  → Binary exists, rebuilding..."
    make build
fi

if [ ! -f "${BINARY_PATH}" ]; then
    echo -e "${RED}Error: Binary not found at ${BINARY_PATH}${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Binary built${NC}"

# ============================================
# STEP 2: Deploy Binary to All Nodes
# ============================================
echo ""
echo -e "${YELLOW}[2/8] Deploying binary to all nodes...${NC}"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo "  → Stopping existing service on ${IP}..."
    ssh "${SSH_USER}@${IP}" "systemctl stop intgd 2>/dev/null || true"
    
    echo "  → Deploying binary to ${IP}..."
    scp "${BINARY_PATH}" "${SSH_USER}@${IP}:/usr/local/bin/intgd"
    ssh "${SSH_USER}@${IP}" "chmod +x /usr/local/bin/intgd"
done
echo -e "${GREEN}  ✓ Binary deployed to all nodes${NC}"

# ============================================
# STEP 3: Initialize Nodes
# ============================================
echo ""
echo -e "${YELLOW}[3/8] Initializing nodes...${NC}"

# Initialize each node with unique moniker
echo "  → Initializing Node 1..."
ssh "${SSH_USER}@${NODE1_IP}" "rm -rf ${HOME_DIR} && intgd init 'Ormos Validator 1' --chain-id ${CHAIN_ID} --home ${HOME_DIR}"

echo "  → Initializing Node 2..."
ssh "${SSH_USER}@${NODE2_IP}" "rm -rf ${HOME_DIR} && intgd init 'Ormos Validator 2' --chain-id ${CHAIN_ID} --home ${HOME_DIR}"

echo "  → Initializing Node 3..."
ssh "${SSH_USER}@${NODE3_IP}" "rm -rf ${HOME_DIR} && intgd init 'Ormos Validator 3' --chain-id ${CHAIN_ID} --home ${HOME_DIR}"

echo -e "${GREEN}  ✓ Nodes initialized${NC}"

# ============================================
# STEP 4: Create Validator Keys
# ============================================
echo ""
echo -e "${YELLOW}[4/8] Creating validator keys...${NC}"

# Node 1
echo "  → Creating key on Node 1..."
VAL1_OUTPUT=$(ssh "${SSH_USER}@${NODE1_IP}" "intgd keys add validator --keyring-backend test --home ${HOME_DIR} 2>&1 || intgd keys show validator --keyring-backend test --home ${HOME_DIR} -a 2>&1")
VAL1_ADDR=$(ssh "${SSH_USER}@${NODE1_IP}" "intgd keys show validator --keyring-backend test --home ${HOME_DIR} -a")
echo "    Validator 1: ${VAL1_ADDR}"

# Node 2
echo "  → Creating key on Node 2..."
VAL2_OUTPUT=$(ssh "${SSH_USER}@${NODE2_IP}" "intgd keys add validator --keyring-backend test --home ${HOME_DIR} 2>&1 || intgd keys show validator --keyring-backend test --home ${HOME_DIR} -a 2>&1")
VAL2_ADDR=$(ssh "${SSH_USER}@${NODE2_IP}" "intgd keys show validator --keyring-backend test --home ${HOME_DIR} -a")
echo "    Validator 2: ${VAL2_ADDR}"

# Node 3
echo "  → Creating key on Node 3..."
VAL3_OUTPUT=$(ssh "${SSH_USER}@${NODE3_IP}" "intgd keys add validator --keyring-backend test --home ${HOME_DIR} 2>&1 || intgd keys show validator --keyring-backend test --home ${HOME_DIR} -a 2>&1")
VAL3_ADDR=$(ssh "${SSH_USER}@${NODE3_IP}" "intgd keys show validator --keyring-backend test --home ${HOME_DIR} -a")
echo "    Validator 3: ${VAL3_ADDR}"

# Create treasury key on Node 1
echo "  → Creating treasury key on Node 1..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd keys add treasury --keyring-backend test --home ${HOME_DIR} 2>&1 || true"
TREASURY_ADDR=$(ssh "${SSH_USER}@${NODE1_IP}" "intgd keys show treasury --keyring-backend test --home ${HOME_DIR} -a")
echo "    Treasury: ${TREASURY_ADDR}"

# Create faucet key on Node 1
echo "  → Creating faucet key on Node 1..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd keys add faucet --keyring-backend test --home ${HOME_DIR} 2>&1 || true"
FAUCET_ADDR=$(ssh "${SSH_USER}@${NODE1_IP}" "intgd keys show faucet --keyring-backend test --home ${HOME_DIR} -a")
echo "    Faucet: ${FAUCET_ADDR}"

# Get EVM addresses
TREASURY_EVM=$(ssh "${SSH_USER}@${NODE1_IP}" "intgd keys show treasury --keyring-backend test --home ${HOME_DIR} --output json" | jq -r '.address' | xargs -I {} sh -c "intgd debug addr {} 2>/dev/null | grep 'Hex:' | awk '{print \$2}'" || echo "")
FAUCET_EVM=$(ssh "${SSH_USER}@${NODE1_IP}" "intgd keys show faucet --keyring-backend test --home ${HOME_DIR} --output json" | jq -r '.address' | xargs -I {} sh -c "intgd debug addr {} 2>/dev/null | grep 'Hex:' | awk '{print \$2}'" || echo "")

echo -e "${GREEN}  ✓ Keys created${NC}"

# ============================================
# STEP 5: Build Genesis
# ============================================
echo ""
echo -e "${YELLOW}[5/8] Building genesis file...${NC}"

# Create base genesis on Node 1
echo "  → Creating base genesis..."

# Add accounts to genesis
echo "  → Adding treasury account..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis add-genesis-account ${TREASURY_ADDR} ${TREASURY_BALANCE}${BASE_DENOM} --home ${HOME_DIR}"

echo "  → Adding faucet account..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis add-genesis-account ${FAUCET_ADDR} ${FAUCET_BALANCE}${BASE_DENOM} --home ${HOME_DIR}"

echo "  → Adding validator 1 account..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis add-genesis-account ${VAL1_ADDR} ${VALIDATOR_STAKE}${BASE_DENOM} --home ${HOME_DIR}"

echo "  → Adding validator 2 account..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis add-genesis-account ${VAL2_ADDR} ${VALIDATOR_STAKE}${BASE_DENOM} --home ${HOME_DIR}"

echo "  → Adding validator 3 account..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis add-genesis-account ${VAL3_ADDR} ${VALIDATOR_STAKE}${BASE_DENOM} --home ${HOME_DIR}"

# Customize genesis parameters
echo "  → Customizing genesis parameters..."
ssh "${SSH_USER}@${NODE1_IP}" "cat ${HOME_DIR}/config/genesis.json | jq '
  # Staking parameters - 1 day unbonding for testnet
  .app_state.staking.params.unbonding_time = \"86400s\" |
  .app_state.staking.params.max_validators = 100 |
  .app_state.staking.params.bond_denom = \"${BASE_DENOM}\" |
  
  # Mint parameters - 3% inflation
  .app_state.mint.minter.inflation = \"0.030000000000000000\" |
  .app_state.mint.params.mint_denom = \"${BASE_DENOM}\" |
  .app_state.mint.params.inflation_rate_change = \"0.030000000000000000\" |
  .app_state.mint.params.inflation_max = \"0.050000000000000000\" |
  .app_state.mint.params.inflation_min = \"0.010000000000000000\" |
  .app_state.mint.params.goal_bonded = \"0.001000000000000000\" |
  
  # Governance - faster for testnet (1 hour)
  .app_state.gov.params.voting_period = \"3600s\" |
  .app_state.gov.params.max_deposit_period = \"3600s\" |
  .app_state.gov.params.expedited_voting_period = \"1800s\" |
  .app_state.gov.params.min_deposit = [{\"denom\": \"${BASE_DENOM}\", \"amount\": \"1000000000000000000000\"}] |
  
  # EVM parameters
  .app_state.evm.params.evm_denom = \"${BASE_DENOM}\" |
  
  # Fee market - low fees for testnet
  .app_state.feemarket.params.base_fee = \"1000000000.000000000000000000\" |
  .app_state.feemarket.params.min_gas_price = \"0.000000000000000000\" |
  
  # Distribution - 0% community tax
  .app_state.distribution.params.community_tax = \"0.000000000000000000\" |
  
  # Denom metadata
  .app_state.bank.denom_metadata = [{
    \"description\": \"The native token of Ormos Testnet\",
    \"denom_units\": [
      {\"denom\": \"${BASE_DENOM}\", \"exponent\": 0, \"aliases\": [\"attoirl\"]},
      {\"denom\": \"oirl\", \"exponent\": 18, \"aliases\": []}
    ],
    \"base\": \"${BASE_DENOM}\",
    \"display\": \"oirl\",
    \"name\": \"Ormos IRL\",
    \"symbol\": \"oIRL\"
  }]
' > ${HOME_DIR}/config/genesis_temp.json && mv ${HOME_DIR}/config/genesis_temp.json ${HOME_DIR}/config/genesis.json"

echo -e "${GREEN}  ✓ Genesis parameters set${NC}"

# ============================================
# STEP 6: Create and Collect GenTxs
# ============================================
echo ""
echo -e "${YELLOW}[6/8] Creating and collecting gentxs...${NC}"

# Copy genesis to all nodes first
echo "  → Distributing genesis to all nodes..."
scp "${SSH_USER}@${NODE1_IP}:${HOME_DIR}/config/genesis.json" "/tmp/testnet_genesis.json"
scp "/tmp/testnet_genesis.json" "${SSH_USER}@${NODE2_IP}:${HOME_DIR}/config/genesis.json"
scp "/tmp/testnet_genesis.json" "${SSH_USER}@${NODE3_IP}:${HOME_DIR}/config/genesis.json"

# Create gentx on each node
echo "  → Creating gentx on Node 1..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis gentx validator ${VALIDATOR_STAKE}${BASE_DENOM} \
    --chain-id ${CHAIN_ID} \
    --keyring-backend test \
    --home ${HOME_DIR} \
    --moniker 'Ormos Validator 1' \
    --commission-rate 0.10 \
    --commission-max-rate 0.20 \
    --commission-max-change-rate 0.01 \
    --min-self-delegation 1 \
    --gas-prices 0${BASE_DENOM}"

echo "  → Creating gentx on Node 2..."
ssh "${SSH_USER}@${NODE2_IP}" "intgd genesis gentx validator ${VALIDATOR_STAKE}${BASE_DENOM} \
    --chain-id ${CHAIN_ID} \
    --keyring-backend test \
    --home ${HOME_DIR} \
    --moniker 'Ormos Validator 2' \
    --commission-rate 0.10 \
    --commission-max-rate 0.20 \
    --commission-max-change-rate 0.01 \
    --min-self-delegation 1 \
    --gas-prices 0${BASE_DENOM}"

echo "  → Creating gentx on Node 3..."
ssh "${SSH_USER}@${NODE3_IP}" "intgd genesis gentx validator ${VALIDATOR_STAKE}${BASE_DENOM} \
    --chain-id ${CHAIN_ID} \
    --keyring-backend test \
    --home ${HOME_DIR} \
    --moniker 'Ormos Validator 3' \
    --commission-rate 0.10 \
    --commission-max-rate 0.20 \
    --commission-max-change-rate 0.01 \
    --min-self-delegation 1 \
    --gas-prices 0${BASE_DENOM}"

# Collect all gentxs to Node 1
echo "  → Collecting gentxs to Node 1..."
mkdir -p "${SCRIPT_DIR}/gentxs"
rm -f "${SCRIPT_DIR}/gentxs"/*.json

scp "${SSH_USER}@${NODE1_IP}:${HOME_DIR}/config/gentx/*.json" "${SCRIPT_DIR}/gentxs/" 2>/dev/null || true
scp "${SSH_USER}@${NODE2_IP}:${HOME_DIR}/config/gentx/*.json" "${SCRIPT_DIR}/gentxs/" 2>/dev/null || true
scp "${SSH_USER}@${NODE3_IP}:${HOME_DIR}/config/gentx/*.json" "${SCRIPT_DIR}/gentxs/" 2>/dev/null || true

# Copy all gentxs to Node 1
for f in "${SCRIPT_DIR}/gentxs"/*.json; do
    [ -f "$f" ] && scp "$f" "${SSH_USER}@${NODE1_IP}:${HOME_DIR}/config/gentx/"
done

# Collect gentxs
echo "  → Running collect-gentxs..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis collect-gentxs --home ${HOME_DIR}"

# Validate genesis
echo "  → Validating genesis..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis validate-genesis --home ${HOME_DIR}"

# Save final genesis
scp "${SSH_USER}@${NODE1_IP}:${HOME_DIR}/config/genesis.json" "${SCRIPT_DIR}/genesis_final.json"

# Distribute final genesis
echo "  → Distributing final genesis..."
scp "${SCRIPT_DIR}/genesis_final.json" "${SSH_USER}@${NODE2_IP}:${HOME_DIR}/config/genesis.json"
scp "${SCRIPT_DIR}/genesis_final.json" "${SSH_USER}@${NODE3_IP}:${HOME_DIR}/config/genesis.json"

echo -e "${GREEN}  ✓ Genesis complete with validators${NC}"

# ============================================
# STEP 7: Configure Peers
# ============================================
echo ""
echo -e "${YELLOW}[7/8] Configuring peers...${NC}"

# Get node IDs
NODE1_ID=$(ssh "${SSH_USER}@${NODE1_IP}" "intgd tendermint show-node-id --home ${HOME_DIR}")
NODE2_ID=$(ssh "${SSH_USER}@${NODE2_IP}" "intgd tendermint show-node-id --home ${HOME_DIR}")
NODE3_ID=$(ssh "${SSH_USER}@${NODE3_IP}" "intgd tendermint show-node-id --home ${HOME_DIR}")

echo "  Node IDs:"
echo "    Node 1: ${NODE1_ID}"
echo "    Node 2: ${NODE2_ID}"
echo "    Node 3: ${NODE3_ID}"

# Build persistent peers string
PEERS="${NODE1_ID}@${NODE1_IP}:${P2P_PORT},${NODE2_ID}@${NODE2_IP}:${P2P_PORT},${NODE3_ID}@${NODE3_IP}:${P2P_PORT}"

# Configure each node
for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo "  → Configuring ${IP}..."
    ssh "${SSH_USER}@${IP}" "sed -i 's/persistent_peers = \"\"/persistent_peers = \"${PEERS}\"/g' ${HOME_DIR}/config/config.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/addr_book_strict = true/addr_book_strict = false/g' ${HOME_DIR}/config/config.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/allow_duplicate_ip = false/allow_duplicate_ip = true/g' ${HOME_DIR}/config/config.toml"
    
    # Enable JSON-RPC
    ssh "${SSH_USER}@${IP}" "sed -i 's/enable = false/enable = true/g' ${HOME_DIR}/config/app.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/address = \"127.0.0.1:8545\"/address = \"0.0.0.0:8545\"/g' ${HOME_DIR}/config/app.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/ws-address = \"127.0.0.1:8546\"/ws-address = \"0.0.0.0:8546\"/g' ${HOME_DIR}/config/app.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/api = \"eth,net,web3\"/api = \"eth,txpool,personal,net,debug,web3\"/g' ${HOME_DIR}/config/app.toml"
    
    # Enable API
    ssh "${SSH_USER}@${IP}" "sed -i 's/enable = false/enable = true/g' ${HOME_DIR}/config/app.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/address = \"tcp:\/\/localhost:1317\"/address = \"tcp:\/\/0.0.0.0:1317\"/g' ${HOME_DIR}/config/app.toml"
    
    # Allow CORS
    ssh "${SSH_USER}@${IP}" "sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = [\"*\"]/g' ${HOME_DIR}/config/config.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g' ${HOME_DIR}/config/app.toml"
    
    # External address
    ssh "${SSH_USER}@${IP}" "sed -i 's/external_address = \"\"/external_address = \"${IP}:${P2P_PORT}\"/g' ${HOME_DIR}/config/config.toml"
    
    # Bind to all interfaces
    ssh "${SSH_USER}@${IP}" "sed -i 's/laddr = \"tcp:\/\/127.0.0.1:26657\"/laddr = \"tcp:\/\/0.0.0.0:26657\"/g' ${HOME_DIR}/config/config.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/laddr = \"tcp:\/\/0.0.0.0:26656\"/laddr = \"tcp:\/\/0.0.0.0:26656\"/g' ${HOME_DIR}/config/config.toml"
done

echo -e "${GREEN}  ✓ Peers configured${NC}"

# ============================================
# STEP 8: Setup Systemd and Start
# ============================================
echo ""
echo -e "${YELLOW}[8/8] Setting up systemd and starting nodes...${NC}"

# Create systemd service
SYSTEMD_SERVICE="[Unit]
Description=Integra Testnet Node
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/intgd start --home ${HOME_DIR}
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo "  → Setting up systemd on ${IP}..."
    ssh "${SSH_USER}@${IP}" "cat > /etc/systemd/system/intgd.service << 'EOF'
${SYSTEMD_SERVICE}
EOF"
    ssh "${SSH_USER}@${IP}" "systemctl daemon-reload"
    ssh "${SSH_USER}@${IP}" "systemctl enable intgd"
done

# Start nodes
echo "  → Starting nodes..."
for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    ssh "${SSH_USER}@${IP}" "systemctl start intgd"
    sleep 3
done

echo ""
echo "Waiting 20 seconds for network to produce blocks..."
sleep 20

# ============================================
# Status Check
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   Testnet Status${NC}"
echo -e "${CYAN}============================================${NC}"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo ""
    echo "--- ${IP} ---"
    if curl -s "http://${IP}:${RPC_PORT}/status" > /dev/null 2>&1; then
        STATUS=$(curl -s "http://${IP}:${RPC_PORT}/status")
        HEIGHT=$(echo "${STATUS}" | jq -r '.result.sync_info.latest_block_height')
        VP=$(echo "${STATUS}" | jq -r '.result.validator_info.voting_power')
        echo -e "  Status: ${GREEN}Online${NC}"
        echo "  Block:  ${HEIGHT}"
        echo "  Power:  ${VP}"
    else
        echo -e "  Status: ${RED}Not responding${NC}"
        ssh "${SSH_USER}@${IP}" "journalctl -u intgd -n 5 --no-pager" 2>/dev/null || true
    fi
done

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   ORMOS TESTNET SETUP COMPLETE!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Chain Configuration:"
echo "  Chain ID (Cosmos): ${CHAIN_ID}"
echo "  Chain ID (EVM):    ${EVM_CHAIN_ID}"
echo "  Token Symbol:      oIRL"
echo "  Token Denom:       ${BASE_DENOM}"
echo ""
echo "Endpoints:"
echo "  RPC:     http://${NODE1_IP}:${RPC_PORT}"
echo "  EVM:     http://${NODE1_IP}:${EVM_RPC_PORT}"
echo "  REST:    http://${NODE1_IP}:${API_PORT}"
echo ""
echo "Key Addresses:"
echo "  Treasury: ${TREASURY_ADDR}"
echo "  Faucet:   ${FAUCET_ADDR}"
echo ""
echo "Validator Addresses:"
echo "  Val 1: ${VAL1_ADDR}"
echo "  Val 2: ${VAL2_ADDR}"
echo "  Val 3: ${VAL3_ADDR}"
echo ""
echo "Files saved:"
echo "  Genesis: ${SCRIPT_DIR}/genesis_final.json"
echo ""
echo -e "${YELLOW}IMPORTANT: Export faucet private key for the faucet service:${NC}"
echo "  ssh ${SSH_USER}@${NODE1_IP} 'intgd keys export faucet --keyring-backend test --home ${HOME_DIR} --unarmored-hex --unsafe'"
echo ""
