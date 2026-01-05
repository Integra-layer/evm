#!/bin/bash
# ============================================
# Script: 03-init-genesis.sh
# Purpose: Initialize genesis file and validator keys
# Run: Execute on your LOCAL machine to generate all configs
# ============================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/.."
source "${DEPLOY_DIR}/config.env"

# Output directory for generated files
OUTPUT_DIR="${DEPLOY_DIR}/generated"
GENTXS_DIR="${OUTPUT_DIR}/gentxs"

echo "============================================"
echo "Initializing Integra Genesis"
echo "============================================"
echo ""
echo "Chain ID: ${CHAIN_ID}"
echo "EVM Chain ID: ${EVM_CHAIN_ID}"
echo "Token: ${DISPLAY_DENOM} (${BASE_DENOM})"
echo ""

# Clean up previous generated files
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${GENTXS_DIR}"

# Create mnemonic storage file
MNEMONICS_FILE="${OUTPUT_DIR}/validator_mnemonics.txt"
echo "============================================" > "${MNEMONICS_FILE}"
echo "INTEGRA NETWORK VALIDATOR MNEMONICS" >> "${MNEMONICS_FILE}"
echo "KEEP THIS FILE SECURE - DO NOT SHARE!" >> "${MNEMONICS_FILE}"
echo "Generated: $(date)" >> "${MNEMONICS_FILE}"
echo "Chain ID: ${CHAIN_ID}" >> "${MNEMONICS_FILE}"
echo "============================================" >> "${MNEMONICS_FILE}"
echo "" >> "${MNEMONICS_FILE}"

# Function to initialize a validator node
init_validator() {
    local NODE_NUM=$1
    local NODE_IP=$2
    local MONIKER=$3
    
    echo ""
    echo "--------------------------------------------"
    echo "Initializing Validator ${NODE_NUM}: ${MONIKER}"
    echo "--------------------------------------------"
    
    local NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    
    # Initialize the node
    ${BINARY_NAME} init "${MONIKER}" --chain-id "${CHAIN_ID}" --home "${NODE_HOME}" 2>/dev/null
    
    # Generate validator key and capture mnemonic
    echo "Generating validator key..."
    local KEY_OUTPUT=$(${BINARY_NAME} keys add "validator${NODE_NUM}" \
        --keyring-backend test \
        --algo eth_secp256k1 \
        --home "${NODE_HOME}" 2>&1)
    
    # Extract mnemonic (last line with 24 words)
    local MNEMONIC=$(echo "${KEY_OUTPUT}" | tail -1)
    
    # Get address
    local VALIDATOR_ADDR=$(${BINARY_NAME} keys show "validator${NODE_NUM}" \
        --keyring-backend test \
        --home "${NODE_HOME}" \
        -a)
    
    # Get validator operator address
    local VALOPER_ADDR=$(${BINARY_NAME} keys show "validator${NODE_NUM}" \
        --keyring-backend test \
        --home "${NODE_HOME}" \
        --bech val -a)
    
    # Save mnemonic to file
    echo "Validator ${NODE_NUM} (${MONIKER})" >> "${MNEMONICS_FILE}"
    echo "  IP: ${NODE_IP}" >> "${MNEMONICS_FILE}"
    echo "  Address: ${VALIDATOR_ADDR}" >> "${MNEMONICS_FILE}"
    echo "  ValOper: ${VALOPER_ADDR}" >> "${MNEMONICS_FILE}"
    echo "  Mnemonic: ${MNEMONIC}" >> "${MNEMONICS_FILE}"
    echo "" >> "${MNEMONICS_FILE}"
    
    echo "  Address: ${VALIDATOR_ADDR}"
    echo "  ValOper: ${VALOPER_ADDR}"
    
    # Return the address for genesis account creation
    echo "${VALIDATOR_ADDR}"
}

# Initialize all validators
echo ""
echo "[1/5] Initializing validators..."

VAL1_ADDR=$(init_validator 1 "${NODE1_IP}" "${NODE1_MONIKER}")
VAL2_ADDR=$(init_validator 2 "${NODE2_IP}" "${NODE2_MONIKER}")
VAL3_ADDR=$(init_validator 3 "${NODE3_IP}" "${NODE3_MONIKER}")

# Use node1 as the base for genesis
GENESIS_HOME="${OUTPUT_DIR}/node1/${DAEMON_HOME}"
GENESIS="${GENESIS_HOME}/config/genesis.json"
TMP_GENESIS="${GENESIS_HOME}/config/tmp_genesis.json"

echo ""
echo "[2/5] Configuring genesis file..."

# Update genesis with chain configuration
# Set staking denom
jq '.app_state["staking"]["params"]["bond_denom"]="'${BASE_DENOM}'"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Set gov min deposit denom
jq '.app_state["gov"]["params"]["min_deposit"][0]["denom"]="'${BASE_DENOM}'"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"
jq '.app_state["gov"]["params"]["expedited_min_deposit"][0]["denom"]="'${BASE_DENOM}'"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Set EVM denom
jq '.app_state["evm"]["params"]["evm_denom"]="'${BASE_DENOM}'"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Set mint denom
jq '.app_state["mint"]["params"]["mint_denom"]="'${BASE_DENOM}'"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Set bank denom metadata
jq '.app_state["bank"]["denom_metadata"]=[{
  "description": "The native staking token of the Integra Network",
  "denom_units": [
    {"denom": "'${BASE_DENOM}'", "exponent": 0, "aliases": ["attoilr"]},
    {"denom": "milr", "exponent": 9, "aliases": ["milliilr"]},
    {"denom": "'$(echo ${DISPLAY_DENOM} | tr '[:upper:]' '[:lower:]')'", "exponent": 18, "aliases": []}
  ],
  "base": "'${BASE_DENOM}'",
  "display": "'$(echo ${DISPLAY_DENOM} | tr '[:upper:]' '[:lower:]')'",
  "name": "'${TOKEN_NAME}'",
  "symbol": "'${TOKEN_SYMBOL}'",
  "uri": "",
  "uri_hash": ""
}]' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Enable all precompiles
jq '.app_state["evm"]["params"]["active_static_precompiles"]=["0x0000000000000000000000000000000000000100","0x0000000000000000000000000000000000000400","0x0000000000000000000000000000000000000800","0x0000000000000000000000000000000000000801","0x0000000000000000000000000000000000000802","0x0000000000000000000000000000000000000803","0x0000000000000000000000000000000000000804","0x0000000000000000000000000000000000000805","0x0000000000000000000000000000000000000806","0x0000000000000000000000000000000000000807"]' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Set native precompiles for ERC20
jq '.app_state.erc20.native_precompiles=["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"]' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"
jq '.app_state.erc20.token_pairs=[{contract_owner:1,erc20_address:"0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",denom:"'${BASE_DENOM}'",enabled:true}]' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Set block gas limit
jq '.consensus.params.block.max_gas="40000000"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

# Set voting periods (for mainnet, use longer periods)
jq '.app_state["gov"]["params"]["voting_period"]="172800s"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"
jq '.app_state["gov"]["params"]["max_deposit_period"]="172800s"' "${GENESIS}" > "${TMP_GENESIS}" && mv "${TMP_GENESIS}" "${GENESIS}"

echo "Genesis configuration updated"

echo ""
echo "[3/5] Adding genesis accounts..."

# Add genesis accounts for each validator
for NODE_NUM in 1 2 3; do
    NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    ${BINARY_NAME} genesis add-genesis-account "validator${NODE_NUM}" "${GENESIS_ACCOUNT_BALANCE}${BASE_DENOM}" \
        --keyring-backend test \
        --home "${NODE_HOME}"
done

# Copy updated genesis to all nodes
for NODE_NUM in 2 3; do
    cp "${GENESIS}" "${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}/config/genesis.json"
done

echo "Genesis accounts added"

echo ""
echo "[4/5] Creating gentx transactions..."

# Create gentx for each validator
for NODE_NUM in 1 2 3; do
    NODE_HOME="${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}"
    eval MONIKER="\${NODE${NODE_NUM}_MONIKER}"
    
    ${BINARY_NAME} genesis gentx "validator${NODE_NUM}" "${VALIDATOR_STAKE}${BASE_DENOM}" \
        --chain-id "${CHAIN_ID}" \
        --keyring-backend test \
        --home "${NODE_HOME}" \
        --moniker "${MONIKER}" \
        --commission-rate "0.10" \
        --commission-max-rate "0.20" \
        --commission-max-change-rate "0.01" \
        --min-self-delegation "1" \
        --gas-prices "${MIN_GAS_PRICE}"
    
    # Copy gentx to central location
    cp "${NODE_HOME}/config/gentx/"*.json "${GENTXS_DIR}/"
    echo "  Created gentx for validator${NODE_NUM}"
done

# Copy all gentxs to node1 for collection
cp "${GENTXS_DIR}"/*.json "${GENESIS_HOME}/config/gentx/"

echo ""
echo "[5/5] Collecting gentxs and validating genesis..."

# Collect gentxs
${BINARY_NAME} genesis collect-gentxs --home "${GENESIS_HOME}"

# Validate genesis
${BINARY_NAME} genesis validate-genesis --home "${GENESIS_HOME}"

# Copy final genesis to all nodes
for NODE_NUM in 2 3; do
    cp "${GENESIS}" "${OUTPUT_DIR}/node${NODE_NUM}/${DAEMON_HOME}/config/genesis.json"
done

# Also save a backup
cp "${GENESIS}" "${OUTPUT_DIR}/genesis.json"

echo ""
echo "============================================"
echo "Genesis Initialization Complete!"
echo "============================================"
echo ""
echo "Generated files location: ${OUTPUT_DIR}"
echo ""
echo "IMPORTANT: Secure the mnemonics file!"
echo "  ${MNEMONICS_FILE}"
echo ""
echo "Next steps:"
echo "1. Review the validator mnemonics and store them securely"
echo "2. Run 04-configure-nodes.sh to set up node configurations"
echo "3. Deploy files to each server"
echo ""

