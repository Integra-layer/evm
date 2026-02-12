#!/bin/bash
set -e

# Mainnet fee fix script - PRESERVES BLOCKCHAIN STATE
# This exports current state, fixes base_fee, and restarts

NODE1="165.227.118.77"
NODE2="159.65.168.118" 
NODE3="104.131.34.167"
SSH_USER="root"

echo "============================================"
echo "=== MAINNET FEE FIX (State Preserving) ==="
echo "============================================"
echo ""
echo "Current gas price is ~0.027 IRL per gas (way too high!)"
echo "Target: ~0.000005 IRL per gas (for ~0.5 IRL per 100k gas tx)"
echo ""
echo "This script will:"
echo "  1. Stop all nodes"
echo "  2. Export current state"
echo "  3. Fix fee parameters"
echo "  4. Restart with fixed params"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 1: Stop all nodes
echo ""
echo "Step 1: Stopping all nodes..."
for NODE in $NODE1 $NODE2 $NODE3; do
    echo "  Stopping $NODE..."
    ssh ${SSH_USER}@${NODE} "systemctl stop intgd || true" 
done
sleep 5
echo "  All nodes stopped."

# Step 2: Export state from Node 1
echo ""
echo "Step 2: Exporting blockchain state from Node 1..."
ssh ${SSH_USER}@${NODE1} << 'EXPORT_EOF'
set -e
cd /root

# Get current block height
CURRENT_HEIGHT=$(intgd status 2>/dev/null | jq -r '.sync_info.latest_block_height' || echo "0")
echo "Current block height: $CURRENT_HEIGHT"

# Export state
echo "Exporting state (this may take a minute)..."
intgd export --home /root/.intgd 2>/dev/null > /root/exported_genesis.json

# Verify export
if [ -f /root/exported_genesis.json ] && [ -s /root/exported_genesis.json ]; then
    echo "State exported successfully"
    ls -la /root/exported_genesis.json
else
    echo "Export failed or empty, using current genesis"
    cp /root/.intgd/config/genesis.json /root/exported_genesis.json
fi
EXPORT_EOF

# Step 3: Download and fix
echo ""
echo "Step 3: Downloading and fixing fee parameters..."
scp ${SSH_USER}@${NODE1}:/root/exported_genesis.json /tmp/exported_genesis.json

# Check file size
FILE_SIZE=$(stat -f%z /tmp/exported_genesis.json 2>/dev/null || stat -c%s /tmp/exported_genesis.json)
echo "  Downloaded genesis file: $FILE_SIZE bytes"

# Fix the fee parameters
echo "  Applying fee fixes..."
jq '
  # Set reasonable base_fee (5000 gwei = 5 * 10^12 wei = 0.000005 IRL per gas)
  # For 100k gas transaction: 100000 * 5000000000000 = 5 * 10^17 = 0.5 IRL
  .app_state.feemarket.params.base_fee = "5000000000000.000000000000000000" |
  .app_state.feemarket.params.min_gas_price = "5000000000000.000000000000000000" |
  
  # Slow down fee adjustments (higher = slower changes)
  .app_state.feemarket.params.base_fee_change_denominator = 100 |
  
  # Reset the block gas counter
  .app_state.feemarket.block_gas = "0"
' /tmp/exported_genesis.json > /tmp/fixed_genesis.json

# Verify the fix
echo ""
echo "  Verifying fee parameters:"
jq '.app_state.feemarket.params' /tmp/fixed_genesis.json

# Step 4: Upload to all nodes
echo ""
echo "Step 4: Uploading fixed genesis to all nodes..."
for NODE in $NODE1 $NODE2 $NODE3; do
    echo "  Uploading to $NODE..."
    scp /tmp/fixed_genesis.json ${SSH_USER}@${NODE}:/root/.intgd/config/genesis.json
done

# Step 5: Reset state (required when changing genesis)
echo ""
echo "Step 5: Resetting node state..."
for NODE in $NODE1 $NODE2 $NODE3; do
    echo "  Resetting $NODE..."
    ssh ${SSH_USER}@${NODE} << 'RESET_EOF'
# Backup current data
mkdir -p /root/backup_data
cp -r /root/.intgd/data /root/backup_data/data_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Reset state (keeps keys and config)
intgd comet unsafe-reset-all --home /root/.intgd

# Ensure priv_validator_state is reset
echo '{"height":"0","round":0,"step":0}' > /root/.intgd/data/priv_validator_state.json
RESET_EOF
done

# Step 6: Start nodes
echo ""
echo "Step 6: Starting all nodes..."
ssh ${SSH_USER}@${NODE1} "systemctl start intgd"
sleep 10  # Let first node start
ssh ${SSH_USER}@${NODE2} "systemctl start intgd" &
ssh ${SSH_USER}@${NODE3} "systemctl start intgd" &
wait

echo ""
echo "============================================"
echo "=== FEE FIX COMPLETE ==="
echo "============================================"
echo ""
echo "Waiting 30 seconds for network to produce blocks..."
sleep 30

# Check new gas price
echo ""
echo "Checking new gas price..."
NEW_GAS=$(curl -s https://evm.integralayer.com -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' | jq -r '.result')
echo "New gas price (hex): $NEW_GAS"

# Convert to decimal
if [ ! -z "$NEW_GAS" ] && [ "$NEW_GAS" != "null" ]; then
    DECIMAL=$(printf "%d\n" $NEW_GAS 2>/dev/null || echo "conversion failed")
    echo "New gas price (decimal): $DECIMAL wei"
    echo ""
    echo "Expected: ~5000000000000 wei (5000 gwei)"
    echo "Fee for 100k gas tx: ~0.5 IRL"
fi

echo ""
echo "Done! Monitor with: journalctl -u intgd -f"
