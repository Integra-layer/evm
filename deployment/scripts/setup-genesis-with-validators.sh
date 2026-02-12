#!/bin/bash
# ============================================
# Script: setup-genesis-with-validators.sh
# Purpose: Build complete genesis with validators and deploy
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/.."
source "${DEPLOY_DIR}/config.env"

SSH_USER="${SSH_USER:-root}"
GENESIS_TEMPLATE="${DEPLOY_DIR}/mainnet/genesis.json"
FINAL_GENESIS="${DEPLOY_DIR}/mainnet/genesis_final.json"

# Validator stake: 1 Billion IRL = 1,000,000,000 * 10^18 airl
VALIDATOR_STAKE="1000000000000000000000000000"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   Integra Mainnet Genesis Setup${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Validator addresses (from the nodes)
VAL1_ADDR="integra1y6976f54tsutugt8ftakptyelsn6cseseg23a7"
VAL2_ADDR="integra1ug9r60rn4myfzk44ra85v9alnk49t7c0lxjryl"
VAL3_ADDR="integra13skys0a5lgqc2ws38teunr5uu520pxcufq5x4h"

# Treasury address (holds remaining supply)
TREASURY_ADDR="integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw"

# Validator operator addresses
VAL1_VALOPER="integravaloper1y6976f54tsutugt8ftakptyelsn6cseslkd7zn"
VAL2_VALOPER="integravaloper1ug9r60rn4myfzk44ra85v9alnk49t7c0ec4vmj"
VAL3_VALOPER="integravaloper13skys0a5lgqc2ws38teunr5uu520pxcu07nf26"

# Consensus pubkeys
VAL1_PUBKEY='{"@type":"/cosmos.crypto.ed25519.PubKey","key":"Fw/KHjlW7D/RtBNKUYLIOyWZPQ0NDl7E9p98YXdLxj4="}'
VAL2_PUBKEY='{"@type":"/cosmos.crypto.ed25519.PubKey","key":"IDL0MM4O5x+ScC+m7ttwF95Wy3/e1zt3tz+68aHJhMs="}'
VAL3_PUBKEY='{"@type":"/cosmos.crypto.ed25519.PubKey","key":"8EtKg293voVcvBaGvf15bV0iTjvGiYllKhKrJNz0Cpk="}'

echo "Configuration:"
echo "  Chain ID:        ${CHAIN_ID}"
echo "  Token:           ${TOKEN_SYMBOL} (${BASE_DENOM})"
echo "  Validator Stake: 1,000,000,000 IRL each"
echo ""
echo "Validators:"
echo "  1. ${VAL1_ADDR}"
echo "  2. ${VAL2_ADDR}"
echo "  3. ${VAL3_ADDR}"
echo ""
echo "Treasury: ${TREASURY_ADDR}"
echo ""

read -p "Continue with genesis setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${YELLOW}[1/6] Stopping all nodes...${NC}"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo "  → Stopping node at ${IP}..."
    ssh "${SSH_USER}@${IP}" "systemctl stop intgd 2>/dev/null || true"
done
sleep 3

echo ""
echo -e "${YELLOW}[2/6] Resetting chain data on all nodes...${NC}"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo "  → Resetting ${IP}..."
    ssh "${SSH_USER}@${IP}" "intgd comet unsafe-reset-all --home /root/.intgd --keep-addr-book 2>/dev/null || intgd tendermint unsafe-reset-all --home /root/.intgd --keep-addr-book 2>/dev/null || true"
done

echo ""
echo -e "${YELLOW}[3/6] Building genesis with validator accounts...${NC}"

# Copy template genesis
cp "${GENESIS_TEMPLATE}" "${FINAL_GENESIS}"

# Calculate treasury balance (100B - 3B for validators = 97B IRL)
# 97,000,000,000 * 10^18 = 97000000000000000000000000000
TREASURY_BALANCE="97000000000000000000000000000"

# Update accounts in genesis
echo "  → Adding validator accounts..."

# Use jq to add all accounts and balances
jq --arg val1 "${VAL1_ADDR}" \
   --arg val2 "${VAL2_ADDR}" \
   --arg val3 "${VAL3_ADDR}" \
   --arg treasury "${TREASURY_ADDR}" \
   --arg val_stake "${VALIDATOR_STAKE}" \
   --arg treasury_bal "${TREASURY_BALANCE}" \
   '
   # Add accounts
   .app_state.auth.accounts = [
     {"@type": "/cosmos.auth.v1beta1.BaseAccount", "address": $treasury, "pub_key": null, "account_number": "0", "sequence": "0"},
     {"@type": "/cosmos.auth.v1beta1.BaseAccount", "address": $val1, "pub_key": null, "account_number": "1", "sequence": "0"},
     {"@type": "/cosmos.auth.v1beta1.BaseAccount", "address": $val2, "pub_key": null, "account_number": "2", "sequence": "0"},
     {"@type": "/cosmos.auth.v1beta1.BaseAccount", "address": $val3, "pub_key": null, "account_number": "3", "sequence": "0"}
   ] |
   # Add balances
   .app_state.bank.balances = [
     {"address": $treasury, "coins": [{"denom": "airl", "amount": $treasury_bal}]},
     {"address": $val1, "coins": [{"denom": "airl", "amount": $val_stake}]},
     {"address": $val2, "coins": [{"denom": "airl", "amount": $val_stake}]},
     {"address": $val3, "coins": [{"denom": "airl", "amount": $val_stake}]}
   ] |
   # Update total supply (100B IRL)
   .app_state.bank.supply = [{"denom": "airl", "amount": "100000000000000000000000000000"}]
   ' "${FINAL_GENESIS}" > "${FINAL_GENESIS}.tmp" && mv "${FINAL_GENESIS}.tmp" "${FINAL_GENESIS}"

echo -e "${GREEN}  ✓ Accounts added${NC}"

echo ""
echo -e "${YELLOW}[4/6] Deploying genesis to all nodes...${NC}"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo "  → Deploying to ${IP}..."
    scp "${FINAL_GENESIS}" "${SSH_USER}@${IP}:/root/.intgd/config/genesis.json"
done

echo ""
echo -e "${YELLOW}[5/6] Creating gentxs on each node...${NC}"

# Create gentx directory
mkdir -p "${DEPLOY_DIR}/mainnet/gentxs"
rm -f "${DEPLOY_DIR}/mainnet/gentxs"/*.json

# Node 1 gentx
echo "  → Creating gentx on Node 1..."
ssh "${SSH_USER}@${NODE1_IP}" "cd /root && intgd genesis gentx validator1 ${VALIDATOR_STAKE}airl \
    --chain-id ${CHAIN_ID} \
    --keyring-backend test \
    --home /root/.intgd \
    --moniker 'Integra Validator 1' \
    --commission-rate 0.10 \
    --commission-max-rate 0.20 \
    --commission-max-change-rate 0.01 \
    --min-self-delegation 1 \
    --gas-prices 0airl 2>&1 || echo 'gentx may already exist'"
scp "${SSH_USER}@${NODE1_IP}:/root/.intgd/config/gentx/*.json" "${DEPLOY_DIR}/mainnet/gentxs/" 2>/dev/null || true

# Node 2 gentx
echo "  → Creating gentx on Node 2..."
ssh "${SSH_USER}@${NODE2_IP}" "cd /root && intgd genesis gentx validator2 ${VALIDATOR_STAKE}airl \
    --chain-id ${CHAIN_ID} \
    --keyring-backend test \
    --home /root/.intgd \
    --moniker 'Integra Validator 2' \
    --commission-rate 0.10 \
    --commission-max-rate 0.20 \
    --commission-max-change-rate 0.01 \
    --min-self-delegation 1 \
    --gas-prices 0airl 2>&1 || echo 'gentx may already exist'"
scp "${SSH_USER}@${NODE2_IP}:/root/.intgd/config/gentx/*.json" "${DEPLOY_DIR}/mainnet/gentxs/" 2>/dev/null || true

# Node 3 gentx
echo "  → Creating gentx on Node 3..."
ssh "${SSH_USER}@${NODE3_IP}" "cd /root && intgd genesis gentx validator3 ${VALIDATOR_STAKE}airl \
    --chain-id ${CHAIN_ID} \
    --keyring-backend test \
    --home /root/.intgd \
    --moniker 'Integra Validator 3' \
    --commission-rate 0.10 \
    --commission-max-rate 0.20 \
    --commission-max-change-rate 0.01 \
    --min-self-delegation 1 \
    --gas-prices 0airl 2>&1 || echo 'gentx may already exist'"
scp "${SSH_USER}@${NODE3_IP}:/root/.intgd/config/gentx/*.json" "${DEPLOY_DIR}/mainnet/gentxs/" 2>/dev/null || true

echo "  → Collected gentxs:"
ls -la "${DEPLOY_DIR}/mainnet/gentxs/" 2>/dev/null || echo "    No gentxs found locally"

# Collect gentxs into genesis on Node 1
echo "  → Collecting gentxs on Node 1..."

# Copy all gentxs to Node 1
for f in "${DEPLOY_DIR}/mainnet/gentxs"/*.json; do
    [ -f "$f" ] && scp "$f" "${SSH_USER}@${NODE1_IP}:/root/.intgd/config/gentx/"
done

# Run collect-gentxs
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis collect-gentxs --home /root/.intgd 2>&1 || echo 'Error collecting gentxs'"

# Validate genesis
echo "  → Validating genesis..."
ssh "${SSH_USER}@${NODE1_IP}" "intgd genesis validate-genesis --home /root/.intgd"

# Copy final genesis back
echo "  → Retrieving final genesis..."
scp "${SSH_USER}@${NODE1_IP}:/root/.intgd/config/genesis.json" "${FINAL_GENESIS}"

# Deploy final genesis to all nodes
echo "  → Deploying final genesis to all nodes..."
for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    scp "${FINAL_GENESIS}" "${SSH_USER}@${IP}:/root/.intgd/config/genesis.json"
done

echo -e "${GREEN}  ✓ Genesis complete with validators${NC}"

echo ""
echo -e "${YELLOW}[6/6] Starting all nodes...${NC}"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo "  → Starting ${IP}..."
    ssh "${SSH_USER}@${IP}" "systemctl start intgd"
    sleep 3
done

echo ""
echo "Waiting 20 seconds for network to produce blocks..."
sleep 20

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}   Network Status${NC}"
echo -e "${CYAN}============================================${NC}"

for IP in ${NODE1_IP} ${NODE2_IP} ${NODE3_IP}; do
    echo ""
    echo "--- ${IP} ---"
    if curl -s "http://${IP}:${RPC_PORT}/status" > /dev/null 2>&1; then
        STATUS=$(curl -s "http://${IP}:${RPC_PORT}/status")
        HEIGHT=$(echo "${STATUS}" | jq -r '.result.sync_info.latest_block_height')
        CATCHING=$(echo "${STATUS}" | jq -r '.result.sync_info.catching_up')
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
echo -e "${GREEN}   MAINNET SETUP COMPLETE!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Endpoints:"
echo "  RPC:     http://${NODE1_IP}:${RPC_PORT}"
echo "  EVM:     http://${NODE1_IP}:${EVM_RPC_PORT}"
echo "  REST:    http://${NODE1_IP}:${API_PORT}"
echo ""
echo "Genesis saved to: ${FINAL_GENESIS}"
echo ""
