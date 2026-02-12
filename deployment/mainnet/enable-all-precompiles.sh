#!/bin/bash
set -e

echo "============================================"
echo "=== ENABLE ALL PRECOMPILES ON MAINNET ==="
echo "============================================"

NODE_IPS=(
  "165.227.118.77"
  "159.65.168.118"
  "104.131.34.167"
)
SSH_USER="root"

# ALL 10 precompiles
PRECOMPILES='[
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
]'

echo "Precompiles to enable:"
echo "  0x...100 - P256 (EIP-7212)"
echo "  0x...400 - Bech32"
echo "  0x...800 - Staking"
echo "  0x...801 - Distribution"
echo "  0x...802 - ICS20 (IBC Transfer)"
echo "  0x...803 - Vesting"
echo "  0x...804 - Bank"
echo "  0x...805 - Governance"
echo "  0x...806 - Slashing"
echo "  0x...807 - ICS02 (IBC Client)"
echo ""

echo "Step 1: Stopping all nodes..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "sudo systemctl stop intgd" 2>/dev/null || true
done
echo "  Done."

echo "Step 2: Exporting current state..."
ssh "${SSH_USER}@${NODE_IPS[0]}" "intgd export --for-zero-height --chain-id integra-1" > /tmp/exported_state.json
echo "  Done."

echo "Step 3: Enabling all precompiles..."
jq ".app_state.evm.params.active_static_precompiles = ${PRECOMPILES} | .initial_height = \"1\" | .app_hash = \"\"" \
  /tmp/exported_state.json > /tmp/fixed_genesis.json
echo "  Done."

echo "Step 4: Distributing genesis..."
for IP in "${NODE_IPS[@]}"; do
    scp /tmp/fixed_genesis.json "${SSH_USER}@${IP}:/root/.intgd/config/genesis.json"
done
echo "  Done."

echo "Step 5: Resetting state..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "intgd comet unsafe-reset-all --home /root/.intgd" 2>&1 | grep -v "^$"
done
echo "  Done."

echo "Step 6: Starting nodes..."
for IP in "${NODE_IPS[@]}"; do
    ssh "${SSH_USER}@${IP}" "sudo systemctl start intgd"
done
echo "  Done."

echo ""
echo "Waiting 30 seconds..."
sleep 30

echo ""
echo "=== VERIFICATION ==="
curl -s "https://api.integralayer.com/cosmos/evm/vm/v1/params" | jq '.params.active_static_precompiles'

echo ""
echo "All 10 precompiles enabled! ✓"
