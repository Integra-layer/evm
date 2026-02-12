#!/bin/bash
set -e

echo "============================================"
echo "=== ENABLE PRECOMPILES ON MAINNET ==="
echo "============================================"
echo ""
echo "This will enable all precompiles including staking."
echo "Network will restart from current state."
echo ""

NODE_IPS=(
  "165.227.118.77"
  "159.65.168.118"
  "104.131.34.167"
)
SSH_USER="root"

# Precompiles to enable
PRECOMPILES='[
  "0x0000000000000000000000000000000000000400",
  "0x0000000000000000000000000000000000000800",
  "0x0000000000000000000000000000000000000801",
  "0x0000000000000000000000000000000000000802",
  "0x0000000000000000000000000000000000000804",
  "0x0000000000000000000000000000000000000805",
  "0x0000000000000000000000000000000000000806",
  "0x0000000000000000000000000000000000000807"
]'

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo "Step 1: Stopping all nodes..."
for IP in "${NODE_IPS[@]}"; do
    echo "  Stopping ${IP}..."
    ssh "${SSH_USER}@${IP}" "sudo systemctl stop intgd" 2>/dev/null || true
done
echo "  All nodes stopped."

echo ""
echo "Step 2: Exporting current state from Node 1..."
ssh "${SSH_USER}@${NODE_IPS[0]}" "intgd export --for-zero-height --chain-id integra-1" > /tmp/exported_state.json
echo "  State exported."

echo ""
echo "Step 3: Enabling precompiles in genesis..."
jq ".app_state.evm.params.active_static_precompiles = ${PRECOMPILES} | .initial_height = \"1\" | .app_hash = \"\"" \
  /tmp/exported_state.json > /tmp/fixed_genesis.json
echo "  Precompiles enabled."

# Verify
echo ""
echo "  Verifying precompiles:"
jq '.app_state.evm.params.active_static_precompiles' /tmp/fixed_genesis.json

echo ""
echo "Step 4: Distributing genesis to all nodes..."
for IP in "${NODE_IPS[@]}"; do
    echo "  Uploading to ${IP}..."
    scp /tmp/fixed_genesis.json "${SSH_USER}@${IP}:/root/.intgd/config/genesis.json"
done

echo ""
echo "Step 5: Resetting chain state on all nodes..."
for IP in "${NODE_IPS[@]}"; do
    echo "  Resetting ${IP}..."
    ssh "${SSH_USER}@${IP}" "intgd comet unsafe-reset-all --home /root/.intgd"
done

echo ""
echo "Step 6: Starting all nodes..."
for IP in "${NODE_IPS[@]}"; do
    echo "  Starting ${IP}..."
    ssh "${SSH_USER}@${IP}" "sudo systemctl start intgd"
done

echo ""
echo "============================================"
echo "=== PRECOMPILES ENABLED ==="
echo "============================================"
echo ""
echo "Waiting 30 seconds for network to start..."
sleep 30

echo "Verifying precompiles are active..."
curl -s "https://api.integralayer.com/cosmos/evm/vm/v1/params" | jq '.params.active_static_precompiles'

echo ""
echo "Done! Staking via EVM should now work."
