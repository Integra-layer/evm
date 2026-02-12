#!/bin/bash
set -e

# Complete mainnet restart script
NODE_IPS=("165.227.118.77" "159.65.168.118" "104.131.34.167")
SSH_USER="root"
CHAIN_ID="integra-1"
BINARY_NAME="intgd"
HOME_DIR=".intgd"

# Genesis parameters
TREASURY_EVM="0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4"
TREASURY_COSMOS="integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw"
TEST_EVM="0x387177b28db10A33C7309a17Ff40fae0Bc787A2E"
TEST_COSMOS="integra18pch0v5dky9r83esngtl7s86uz78s73w48e2dk"
# CORRECT VALUES - 100 Billion IRL total supply
TREASURY_AMOUNT="100000000000000000000000000000"    # 100 Billion IRL (10^29 airl)
TEST_AMOUNT="1000000000000000000000"                # 1,000 IRL
VALIDATOR_AMOUNT="5100000000000000000000"           # 5,100 IRL per validator
TOTAL_SUPPLY="100000016300000000000000000000"       # 100B + 1K + 3*5.1K = 100,000,016,300 IRL

echo "============================================"
echo "=== MAINNET RESTART - COMPLETE RESET ==="
echo "============================================"
echo ""
read -p "This will WIPE ALL DATA. Continue? (yes/NO): " confirm
[[ "$confirm" == "yes" ]] || exit 1

# Step 1: Stop and wipe everything
echo ""
echo "Step 1: Stopping nodes and wiping data..."
for IP in "${NODE_IPS[@]}"; do
    echo "  -> ${IP}..."
    ssh "${SSH_USER}@${IP}" "sudo systemctl stop ${BINARY_NAME}; rm -rf /root/${HOME_DIR}" || true
done

# Step 2: Initialize all nodes
echo ""
echo "Step 2: Initializing nodes..."
for i in "${!NODE_IPS[@]}"; do
    IP=${NODE_IPS[$i]}
    MONIKER="integra-validator-$((i+1))"
    echo "  -> ${IP} (${MONIKER})..."
    ssh "${SSH_USER}@${IP}" "${BINARY_NAME} init ${MONIKER} --chain-id ${CHAIN_ID}"
done

# Step 3: Ensure validator keys exist
echo ""
echo "Step 3: Setting up validator keys..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "${BINARY_NAME} keys show validator --keyring-backend test >/dev/null 2>&1 || ${BINARY_NAME} keys add validator --keyring-backend test >/dev/null 2>&1" || true
done

# Get validator addresses
echo "  -> Getting validator addresses..."
VAL1=$(ssh "${SSH_USER}@${NODE_IPS[0]}" "${BINARY_NAME} keys show validator -a --keyring-backend test")
VAL2=$(ssh "${SSH_USER}@${NODE_IPS[1]}" "${BINARY_NAME} keys show validator -a --keyring-backend test")
VAL3=$(ssh "${SSH_USER}@${NODE_IPS[2]}" "${BINARY_NAME} keys show validator -a --keyring-backend test")
echo "     Val1: ${VAL1}"
echo "     Val2: ${VAL2}"
echo "     Val3: ${VAL3}"

# Step 4: Build genesis on Node 1
echo ""
echo "Step 4: Building genesis on Node 1..."
NODE1=${NODE_IPS[0]}

ssh "${SSH_USER}@${NODE1}" << EOFGENESIS
# Add all accounts
${BINARY_NAME} genesis add-genesis-account ${TREASURY_COSMOS} ${TREASURY_AMOUNT}airl
${BINARY_NAME} genesis add-genesis-account ${TEST_COSMOS} ${TEST_AMOUNT}airl
${BINARY_NAME} genesis add-genesis-account ${VAL1} ${VALIDATOR_AMOUNT}airl
${BINARY_NAME} genesis add-genesis-account ${VAL2} ${VALIDATOR_AMOUNT}airl
${BINARY_NAME} genesis add-genesis-account ${VAL3} ${VALIDATOR_AMOUNT}airl

# Update genesis parameters
cp /root/${HOME_DIR}/config/genesis.json /tmp/genesis_temp.json
jq '
.app_state.bank.denom_metadata = [{
  "description": "Integra Native Token",
  "denom_units": [
    {"denom": "airl", "exponent": 0, "aliases": ["attoirl"]},
    {"denom": "irl", "exponent": 18, "aliases": ["IRL"]}
  ],
  "base": "airl",
  "display": "irl",
  "name": "Integra",
  "symbol": "IRL"
}] |
.app_state.bank.supply = [{"denom": "airl", "amount": "${TOTAL_SUPPLY}"}] |
.app_state.staking.params.bond_denom = "airl" |
.app_state.staking.params.unbonding_time = "1814400s" |
.app_state.staking.params.max_validators = 100 |
.app_state.staking.params.min_commission_rate = "0.000000000000000000" |
.app_state.mint.params.mint_denom = "airl" |
.app_state.mint.params.inflation_rate_change = "0.000000000000000000" |
.app_state.mint.params.inflation_max = "0.030000000000000000" |
.app_state.mint.params.inflation_min = "0.030000000000000000" |
.app_state.mint.minter.inflation = "0.030000000000000000" |
.app_state.mint.params.goal_bonded = "0.001000000000000000" |
.app_state.gov.params.min_deposit = [{"denom": "airl", "amount": "100000000000000000000000000"}] |
.app_state.gov.params.expedited_min_deposit = [{"denom": "airl", "amount": "500000000000000000000000000"}] |
.app_state.gov.params.max_deposit_period = "604800s" |
.app_state.gov.params.voting_period = "604800s" |
.app_state.gov.params.expedited_voting_period = "259200s" |
.app_state.distribution.params.community_tax = "0.000000000000000000" |
.app_state.crisis.constant_fee = {"denom": "airl", "amount": "1000000000000000000000"} |
.app_state.feemarket.params.base_fee = "5000000000000.000000000000000000" |
.app_state.feemarket.params.min_gas_price = "5000000000000.000000000000000000" |
.app_state.evm.params.evm_denom = "airl" |
.app_state.evm.params.active_static_precompiles = [
  "0x0000000000000000000000000000000000000100",
  "0x0000000000000000000000000000000000000400",
  "0x0000000000000000000000000000000000000800",
  "0x0000000000000000000000000000000000000801",
  "0x0000000000000000000000000000000000000802",
  "0x0000000000000000000000000000000000000803",
  "0x0000000000000000000000000000000000000804",
  "0x0000000000000000000000000000000000000805",
  "0x0000000000000000000000000000000000000806",
  "0x0000000000000000000000000000000000000807"
] |
.app_state.erc20.params.enable_erc20 = true
' /tmp/genesis_temp.json > /root/${HOME_DIR}/config/genesis.json

echo "Genesis configured"
EOFGENESIS

# Step 5: Copy genesis to all nodes
echo ""
echo "Step 5: Distributing genesis to all nodes..."
scp "${SSH_USER}@${NODE1}:/root/${HOME_DIR}/config/genesis.json" /tmp/base_genesis.json
for IP in "${NODE_IPS[@]}"; do
    if [[ "${IP}" != "${NODE1}" ]]; then
        echo "  -> ${IP}..."
        scp /tmp/base_genesis.json "${SSH_USER}@${IP}:/root/${HOME_DIR}/config/genesis.json"
    fi
done

# Step 6: Create gentxs WITH fees
echo ""
echo "Step 6: Creating gentxs with fees..."
for i in "${!NODE_IPS[@]}"; do
    IP=${NODE_IPS[$i]}
    MONIKER="integra-validator-$((i+1))"
    echo "  -> ${MONIKER} on ${IP}..."
    ssh "${SSH_USER}@${IP}" "${BINARY_NAME} genesis gentx validator 100000000000000000000airl \
        --chain-id ${CHAIN_ID} \
        --moniker ${MONIKER} \
        --commission-rate 0.05 \
        --commission-max-rate 0.20 \
        --commission-max-change-rate 0.01 \
        --min-self-delegation 1 \
        --keyring-backend test \
        --gas-prices 5000000000000airl \
        --gas 200000"
done

# Step 7: Collect gentxs on Node 1
echo ""
echo "Step 7: Collecting gentxs..."
mkdir -p /tmp/mainnet_gentxs
for i in "${!NODE_IPS[@]}"; do
    IP=${NODE_IPS[$i]}
    scp "${SSH_USER}@${IP}:/root/${HOME_DIR}/config/gentx/*.json" "/tmp/mainnet_gentxs/gentx${i}.json"
done

ssh "${SSH_USER}@${NODE1}" "rm -rf /root/${HOME_DIR}/config/gentx/*.json"
scp /tmp/mainnet_gentxs/*.json "${SSH_USER}@${NODE1}:/root/${HOME_DIR}/config/gentx/"
ssh "${SSH_USER}@${NODE1}" "${BINARY_NAME} genesis collect-gentxs"

# Step 8: Distribute final genesis
echo ""
echo "Step 8: Distributing final genesis..."
scp "${SSH_USER}@${NODE1}:/root/${HOME_DIR}/config/genesis.json" /tmp/final_genesis.json
for IP in "${NODE_IPS[@]}"; do
    if [[ "${IP}" != "${NODE1}" ]]; then
        echo "  -> ${IP}..."
        scp /tmp/final_genesis.json "${SSH_USER}@${IP}:/root/${HOME_DIR}/config/genesis.json"
    fi
done

# Step 9: Setup peers
echo ""
echo "Step 9: Configuring persistent peers..."
NODE1_ID=$(ssh "${SSH_USER}@${NODE_IPS[0]}" "${BINARY_NAME} comet show-node-id")
NODE2_ID=$(ssh "${SSH_USER}@${NODE_IPS[1]}" "${BINARY_NAME} comet show-node-id")
NODE3_ID=$(ssh "${SSH_USER}@${NODE_IPS[2]}" "${BINARY_NAME} comet show-node-id")
PEERS="${NODE1_ID}@${NODE_IPS[0]}:26656,${NODE2_ID}@${NODE_IPS[1]}:26656,${NODE3_ID}@${NODE_IPS[2]}:26656"

for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "sed -i 's/persistent_peers = \"\"/persistent_peers = \"${PEERS}\"/' /root/${HOME_DIR}/config/config.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/minimum-gas-prices = .*/minimum-gas-prices = \"0airl\"/' /root/${HOME_DIR}/config/app.toml"
    ssh "${SSH_USER}@${IP}" "sed -i 's/evm-chain-id = .*/evm-chain-id = 26217/' /root/${HOME_DIR}/config/app.toml"
done

# Step 10: Start nodes
echo ""
echo "Step 10: Starting all nodes..."
for IP in "${NODE_IPS[@]}"; do
    echo "  -> ${IP}..."
    ssh "${SSH_USER}@${IP}" "sudo systemctl start ${BINARY_NAME}"
done

echo ""
echo "============================================"
echo "=== MAINNET RESTARTED ==="
echo "============================================"
echo "Waiting 30 seconds for network to stabilize..."
sleep 30

echo ""
echo "=== Network Status ==="
curl -s "http://${NODE_IPS[0]}:26657/status" | jq '{catching_up: .result.sync_info.catching_up, latest_block: .result.sync_info.latest_block_height}'

echo ""
echo "=== EVM Chain ID ==="
curl -s "http://${NODE_IPS[0]}:8545" -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","id":1}' | jq -r '.result' | xargs printf "Chain ID: %d\n"

echo ""
echo "=== Treasury Balance ==="
curl -s "http://${NODE_IPS[0]}:8545" -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'${TREASURY_EVM}'","latest"],"id":1}' | jq .

echo ""
echo "Done! Network should be running."
