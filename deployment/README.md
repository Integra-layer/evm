# Integra Network Deployment Guide

This guide provides step-by-step instructions for deploying the Integra EVM Network to 3 validator nodes.

## Network Overview

| Property | Value |
|----------|-------|
| **Chain ID** | `integra-1` |
| **EVM Chain ID** | `26217` |
| **Token Symbol** | `IRL` |
| **Base Denomination** | `airl` (atto-IRL, 18 decimals) |
| **Validators** | 3 (equal voting power) |

### Node Information

| Node | IP Address | Role |
|------|------------|------|
| Node 1 | `165.227.118.77` | Validator 1 |
| Node 2 | `159.65.168.118` | Validator 2 |
| Node 3 | `104.131.34.167` | Validator 3 |

### Ports

| Port | Service |
|------|---------|
| 26656 | P2P |
| 26657 | Tendermint RPC |
| 1317 | REST API |
| 9090 | gRPC |
| 8545 | EVM JSON-RPC |
| 8546 | EVM WebSocket |

---

## Prerequisites

### On Your Local Machine

1. **Go 1.22+** installed
2. **SSH access** to all three servers
3. **jq** installed (`brew install jq` on macOS)

### On Each Server

The deployment scripts will install:
- Go 1.22
- Build essentials
- UFW firewall

---

## Deployment Steps

### Step 1: Build the Binary for Linux

On your local machine:

```bash
cd /path/to/integra-evm

# Build for Linux (the target servers)
GOOS=linux GOARCH=amd64 make build

# The binary will be at: build/intgd
```

### Step 2: Set Up SSH Access

Ensure you can SSH to all servers without password:

```bash
# Test SSH access
ssh root@165.227.118.77 "echo 'Node 1 OK'"
ssh root@159.65.168.118 "echo 'Node 2 OK'"
ssh root@104.131.34.167 "echo 'Node 3 OK'"

# If needed, copy your SSH key:
ssh-copy-id root@165.227.118.77
ssh-copy-id root@159.65.168.118
ssh-copy-id root@104.131.34.167
```

### Step 3: Prepare Servers

Run on each server (or use the provided script):

```bash
# SSH into each server and run:
apt-get update && apt-get upgrade -y
apt-get install -y build-essential git curl wget jq make gcc ufw

# Or deploy the prerequisites script:
cd deployment/scripts
chmod +x *.sh
./01-install-prerequisites.sh  # Run via SSH on each server
```

### Step 4: Initialize Genesis and Keys

On your local machine:

```bash
cd deployment/scripts

# Make scripts executable
chmod +x *.sh

# Initialize genesis and generate validator keys
./03-init-genesis.sh

# Configure node settings
./04-configure-nodes.sh
```

This creates:
- `generated/` - All node configurations
- `generated/validator_mnemonics.txt` - **SECURE THIS FILE!**
- `generated/genesis.json` - Network genesis file
- `generated/node_info.txt` - Network endpoints

### Step 5: Deploy to Servers

```bash
# Deploy binary and configs to all servers
./05-deploy-to-servers.sh

# Or deploy manually if SSH automation fails
```

### Step 6: Start the Network

```bash
# Start all nodes
./06-start-network.sh

# Or start manually on each server:
ssh root@165.227.118.77 "systemctl start intgd"
ssh root@159.65.168.118 "systemctl start intgd"
ssh root@104.131.34.167 "systemctl start intgd"
```

---

## Manual Server Setup (Alternative)

If you prefer to set up servers manually:

### On Each Server

```bash
# 1. Install dependencies
apt-get update && apt-get upgrade -y
apt-get install -y build-essential git curl wget jq ufw

# 2. Configure firewall
ufw allow 22/tcp
ufw allow 26656/tcp
ufw allow 26657/tcp
ufw allow 1317/tcp
ufw allow 9090/tcp
ufw allow 8545/tcp
ufw allow 8546/tcp
ufw --force enable

# 3. Copy binary (from your local machine)
# scp build/intgd root@SERVER_IP:/usr/local/bin/
chmod +x /usr/local/bin/intgd

# 4. Create data directory
mkdir -p /root/.intgd

# 5. Copy node configuration (from generated/nodeX/.intgd/)
# scp -r generated/nodeX/.intgd/* root@SERVER_IP:/root/.intgd/

# 6. Copy systemd service
# scp deployment/systemd/intgd.service root@SERVER_IP:/etc/systemd/system/

# 7. Enable and start service
systemctl daemon-reload
systemctl enable intgd
systemctl start intgd

# 8. Check logs
journalctl -u intgd -f
```

---

## Verifying the Network

### Check Node Status

```bash
# Via RPC
curl http://165.227.118.77:26657/status | jq '.result.sync_info'

# Via CLI (on server)
intgd status --home /root/.intgd
```

### Check Validators

```bash
# Query validators
curl http://165.227.118.77:26657/validators | jq '.result.validators'

# Via CLI
intgd query staking validators --home /root/.intgd
```

### Check Block Production

```bash
# Watch latest blocks
watch -n 1 'curl -s http://165.227.118.77:26657/status | jq ".result.sync_info.latest_block_height"'
```

---

## MetaMask Configuration

Add the Integra Network to MetaMask:

| Field | Value |
|-------|-------|
| Network Name | Integra Network |
| RPC URL | `http://165.227.118.77:8545` |
| Chain ID | `26217` |
| Currency Symbol | `IRL` |
| Block Explorer | (leave blank) |

---

## Useful Commands

### Service Management

```bash
# Start node
systemctl start intgd

# Stop node
systemctl stop intgd

# Restart node
systemctl restart intgd

# Check status
systemctl status intgd

# View logs
journalctl -u intgd -f
journalctl -u intgd -n 100 --no-pager
```

### Node Operations

```bash
# Check sync status
intgd status --home /root/.intgd | jq '.sync_info'

# Query balance
intgd query bank balances <address> --home /root/.intgd

# Send tokens
intgd tx bank send <from> <to> <amount>airl \
    --chain-id integra-1 \
    --home /root/.intgd \
    --keyring-backend file \
    --gas auto \
    --gas-adjustment 1.5

# Delegate to validator
intgd tx staking delegate <validator-address> <amount>airl \
    --from <key-name> \
    --chain-id integra-1 \
    --home /root/.intgd \
    --keyring-backend file
```

### Validator Operations

```bash
# Check validator status
intgd query staking validator <valoper-address> --home /root/.intgd

# Unjail validator (if jailed)
intgd tx slashing unjail \
    --from <validator-key> \
    --chain-id integra-1 \
    --home /root/.intgd \
    --keyring-backend file
```

---

## Troubleshooting

### Node Won't Start

```bash
# Check logs
journalctl -u intgd -n 50 --no-pager

# Common issues:
# - Port already in use
# - Genesis file mismatch
# - Wrong chain-id
# - Missing data directory
```

### Peers Not Connecting

```bash
# Check firewall
ufw status

# Verify ports are open
netstat -tlnp | grep intgd

# Check peer configuration
cat /root/.intgd/config/config.toml | grep persistent_peers
```

### Node Stuck Syncing

```bash
# Check peer connections
curl http://localhost:26657/net_info | jq '.result.n_peers'

# Check if other nodes are producing blocks
curl http://165.227.118.77:26657/status | jq '.result.sync_info'
```

---

## Security Recommendations

1. **Secure the mnemonic file** - Store `validator_mnemonics.txt` in a secure location
2. **Use firewall** - Only open necessary ports
3. **SSH keys only** - Disable password authentication
4. **Regular updates** - Keep system packages updated
5. **Monitor nodes** - Set up alerting for downtime
6. **Backup keys** - Backup validator keys regularly

---

## File Structure

```
deployment/
├── config.env                 # Network configuration
├── README.md                  # This file
├── scripts/
│   ├── 01-install-prerequisites.sh
│   ├── 02-setup-firewall.sh
│   ├── 03-init-genesis.sh
│   ├── 04-configure-nodes.sh
│   ├── 05-deploy-to-servers.sh
│   └── 06-start-network.sh
├── systemd/
│   └── intgd.service
└── generated/                 # Created after running scripts
    ├── genesis.json
    ├── validator_mnemonics.txt
    ├── node_info.txt
    ├── node1/
    ├── node2/
    └── node3/
```

---

## Support

For issues with:
- **Deployment scripts**: Check the generated logs
- **Node operation**: Check `journalctl -u intgd -f`
- **Network issues**: Verify firewall and peer configuration

