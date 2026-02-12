#!/bin/bash
set -e

echo "============================================"
echo "=== FRESH MAINNET RESTART ==="
echo "============================================"

NODE_IPS=("165.227.118.77" "159.65.168.118" "104.131.34.167")
SSH_USER="root"
CHAIN_ID="integra-1"
EVM_CHAIN_ID="26217"

# Addresses
TREASURY="integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw"
TEST_ACCOUNT="integra17942lwgne0cqwx0sz9zwtayxp0aadwlqphsp0f"  # 0xf155fa75133f043d0cf421072bab60d1feb676e0

# Amounts (in airl - 18 decimals)
TREASURY_AMOUNT="99999999900000000000000000000000000000"  # ~99.9999999 billion IRL
TEST_AMOUNT="100000000000000000000"  # 100 IRL
VALIDATOR_AMOUNT="5100000000000000000000"  # 5100 IRL each

echo "Step 1: Stopping all nodes..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "sudo systemctl stop intgd" 2>/dev/null || true
done

echo "Step 2: Wiping data on all nodes..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "rm -rf /root/.intgd/data /root/.intgd/config/genesis.json /root/.intgd/config/gentx"
done

echo "Step 3: Initializing nodes..."
VALIDATOR_NAMES=("integra-validator-1" "integra-validator-2" "integra-validator-3")
for i in 0 1 2; do
    ssh "${SSH_USER}@${NODE_IPS[$i]}" "intgd init ${VALIDATOR_NAMES[$i]} --chain-id ${CHAIN_ID} --overwrite"
done

echo "Step 4: Getting validator info..."
# Get validator addresses and pubkeys
declare -A VAL_ADDRS
declare -A VAL_PUBKEYS
for i in 0 1 2; do
    VAL_ADDRS[$i]=$(ssh "${SSH_USER}@${NODE_IPS[$i]}" "intgd keys show validator --bech val -a --keyring-backend test 2>/dev/null || intgd keys add validator --keyring-backend test --output json 2>/dev/null | jq -r '.address' | xargs intgd keys show validator --bech val -a --keyring-backend test")
    echo "Validator $i: ${VAL_ADDRS[$i]}"
done

echo "Step 5: Building genesis on Node 1..."
NODE1="${NODE_IPS[0]}"

ssh "${SSH_USER}@${NODE1}" << REMOTE
set -e

# Add accounts to genesis
intgd genesis add-genesis-account ${TREASURY} ${TREASURY_AMOUNT}airl --keyring-backend test
intgd genesis add-genesis-account ${TEST_ACCOUNT} ${TEST_AMOUNT}airl --keyring-backend test

# Add validator accounts
for addr in \$(intgd keys list --keyring-backend test --output json | jq -r '.[].address'); do
    intgd genesis add-genesis-account \$addr ${VALIDATOR_AMOUNT}airl --keyring-backend test 2>/dev/null || true
done

# Modify genesis with jq
cp /root/.intgd/config/genesis.json /tmp/genesis_base.json

# Add all configurations
jq '
  # Token metadata
  .app_state.bank.denom_metadata = [{
    "description": "Integra Native Token",
    "denom_units": [
      {"denom": "airl", "exponent": 0, "aliases": ["atttoirl"]},
      {"denom": "irl", "exponent": 18, "aliases": ["IRL"]}
    ],
    "base": "airl",
    "display": "irl",
    "name": "Integra",
    "symbol": "IRL"
  }] |
  
  # Staking params
  .app_state.staking.params.bond_denom = "airl" |
  .app_state.staking.params.unbonding_time = "1814400s" |
  .app_state.staking.params.max_validators = 100 |
  
  # Mint params
  .app_state.mint.params.mint_denom = "airl" |
  .app_state.mint.params.inflation_rate_change = "0.000000000000000000" |
  .app_state.mint.params.inflation_max = "0.030000000000000000" |
  .app_state.mint.params.inflation_min = "0.030000000000000000" |
  .app_state.mint.minter.inflation = "0.030000000000000000" |
  .app_state.mint.params.goal_bonded = "0.001000000000000000" |
  
  # Gov params
  .app_state.gov.params.min_deposit = [{"denom": "airl", "amount": "100000000000000000000000000"}] |
  .app_state.gov.params.max_deposit_period = "604800s" |
  .app_state.gov.params.voting_period = "604800s" |
  .app_state.gov.params.expedited_voting_period = "259200s" |
  .app_state.gov.params.quorum = "0.334000000000000000" |
  .app_state.gov.params.threshold = "0.510000000000000000" |
  .app_state.gov.params.veto_threshold = "0.334000000000000000" |
  
  # Distribution
  .app_state.distribution.params.community_tax = "0.000000000000000000" |
  
  # Crisis
  .app_state.crisis.constant_fee.denom = "airl" |
  .app_state.crisis.constant_fee.amount = "1000000000000000000000" |
  
  # Fee market
  .app_state.feemarket.params.base_fee = "5000000000000.000000000000000000" |
  .app_state.feemarket.params.min_gas_price = "5000000000000.000000000000000000" |
  .app_state.feemarket.params.base_fee_change_denominator = 100 |
  
  # EVM params - ALL 10 PRECOMPILES
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
  ]
' /tmp/genesis_base.json > /root/.intgd/config/genesis.json

echo "Genesis built with all params"
REMOTE

echo "Step 6: Creating gentx on each validator..."
for i in 0 1 2; do
    echo "Creating gentx on node $i..."
    ssh "${SSH_USER}@${NODE_IPS[$i]}" << GENTX
    set -e
    # Copy genesis from node 1
    scp -o StrictHostKeyChecking=no root@${NODE1}:/root/.intgd/config/genesis.json /root/.intgd/config/genesis.json 2>/dev/null || true
    
    # Create gentx
    intgd genesis gentx validator 100000000000000000000airl \
        --chain-id ${CHAIN_ID} \
        --moniker "${VALIDATOR_NAMES[$i]}" \
        --commission-rate 0.05 \
        --commission-max-rate 0.20 \
        --commission-max-change-rate 0.01 \
        --min-self-delegation 1 \
        --keyring-backend test
GENTX
done

echo "Step 7: Collecting gentxs..."
mkdir -p /tmp/gentxs
for i in 0 1 2; do
    scp "${SSH_USER}@${NODE_IPS[$i]}:/root/.intgd/config/gentx/*.json" /tmp/gentxs/ 2>/dev/null || true
done

# Upload all gentxs to node 1
scp /tmp/gentxs/*.json "${SSH_USER}@${NODE1}:/root/.intgd/config/gentx/"

# Collect gentxs
ssh "${SSH_USER}@${NODE1}" "intgd genesis collect-gentxs"

echo "Step 8: Distributing final genesis..."
for IP in "${NODE_IPS[@]}"; do
    scp "${SSH_USER}@${NODE1}:/root/.intgd/config/genesis.json" "${SSH_USER}@${IP}:/root/.intgd/config/genesis.json"
done

echo "Step 9: Setting up persistent peers..."
# Get node IDs
declare -A NODE_IDS
for i in 0 1 2; do
    NODE_IDS[$i]=$(ssh "${SSH_USER}@${NODE_IPS[$i]}" "intgd comet show-node-id")
done

PEERS=""
for i in 0 1 2; do
    PEERS+="${NODE_IDS[$i]}@${NODE_IPS[$i]}:26656,"
done
PEERS=${PEERS%,}

for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "sed -i 's/persistent_peers = \"\"/persistent_peers = \"${PEERS}\"/' /root/.intgd/config/config.toml"
done

echo "Step 10: Fixing app.toml EVM chain ID..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "sed -i 's/evm-chain-id = .*/evm-chain-id = ${EVM_CHAIN_ID}/' /root/.intgd/config/app.toml"
done

echo "Step 11: Starting all nodes..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "sudo systemctl start intgd"
done

echo ""
echo "============================================"
echo "=== FRESH RESTART COMPLETE ==="
echo "============================================"
