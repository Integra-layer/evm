# Integra Mainnet Configuration

> **Network:** Integra Mainnet  
> **Chain ID:** `integra-1`  
> **Status:** Production

---

## Network Overview

Integra Mainnet is the production network for the Integra Real World Asset Layer 1 blockchain. This network handles real value transactions and should be used for production deployments.

---

## Quick Reference

| Parameter | Value |
|-----------|-------|
| **Chain ID** | `integra-1` |
| **Network Name** | Integra |
| **Native Token** | IRL |
| **Token Symbol** | IRL |
| **Decimals** | 18 |
| **Base Denom** | `airl` |
| **Address Prefix** | `integra` |
| **Valoper Prefix** | `integravaloper` |

---

## RPC Endpoints

| Service | URL |
|---------|-----|
| **EVM JSON-RPC** | `https://rpc.integralayer.com` |
| **Cosmos RPC** | `https://rpc.integralayer.com:26657` |
| **REST API** | `https://api.integralayer.com` |
| **gRPC** | `grpc.integralayer.com:9090` |
| **WebSocket** | `wss://rpc.integralayer.com/websocket` |
| **Block Explorer** | `https://explorer.integralayer.com` |

---

## EVM Configuration

| Parameter | Value |
|-----------|-------|
| **EVM Chain ID** | `26217` |
| **Currency Symbol** | IRL |
| **Block Explorer** | https://explorer.integralayer.com |

### MetaMask Configuration

```json
{
  "chainId": "0xCCEE",
  "chainName": "Integra Mainnet",
  "nativeCurrency": {
    "name": "Integra",
    "symbol": "IRL",
    "decimals": 18
  },
  "rpcUrls": ["https://rpc.integralayer.com"],
  "blockExplorerUrls": ["https://explorer.integralayer.com"]
}
```

### Hardhat Configuration

```javascript
module.exports = {
  networks: {
    integra: {
      url: "https://rpc.integralayer.com",
      chainId: 26217,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

### Foundry Configuration

```toml
[rpc_endpoints]
integra = "https://rpc.integralayer.com"

[etherscan]
integra = { key = "", chain = 26217, url = "https://explorer.integralayer.com/api" }
```

---

## Token Economics

| Parameter | Value |
|-----------|-------|
| **Total Supply** | 100,000,000,000 IRL |
| **Inflation Rate** | 3% (fixed) |
| **Community Tax** | 2% |

---

## Staking Parameters

| Parameter | Value |
|-----------|-------|
| **Unbonding Period** | 21 days |
| **Max Validators** | 100 |
| **Min Commission** | 0% |
| **Bond Denom** | `airl` |

---

## Governance Parameters

| Parameter | Value |
|-----------|-------|
| **Min Deposit** | 100,000,000 IRL |
| **Deposit Period** | 2 days |
| **Voting Period** | 2 days |
| **Quorum** | 33.4% |
| **Pass Threshold** | 51% |
| **Veto Threshold** | 33.4% |

---

## Genesis Accounts

| Address | Purpose | Balance |
|---------|---------|---------|
| `integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw` | Foundation Treasury | 100B IRL |

### Address Formats

| Format | Address |
|--------|---------|
| Bech32 | `integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw` |
| EVM | `0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4` |

---

## Node Requirements

### Minimum Hardware

| Component | Specification |
|-----------|---------------|
| **CPU** | 4 cores |
| **RAM** | 16 GB |
| **Storage** | 500 GB SSD |
| **Network** | 100 Mbps |

### Recommended Hardware

| Component | Specification |
|-----------|---------------|
| **CPU** | 8 cores |
| **RAM** | 32 GB |
| **Storage** | 1 TB NVMe SSD |
| **Network** | 1 Gbps |

---

## Node Setup

### 1. Initialize Node

```bash
# Set chain ID
export CHAIN_ID="integra-1"

# Initialize node
integrad init <moniker> --chain-id $CHAIN_ID

# Copy genesis file
cp genesis.json ~/.integra/config/genesis.json
```

### 2. Configure Seeds/Peers

```bash
# Add seeds to config.toml
seeds="<seed_node_id>@<seed_ip>:26656"
sed -i "s/^seeds =.*/seeds = \"$seeds\"/" ~/.integra/config/config.toml
```

### 3. Start Node

```bash
# Start node
integrad start

# Or with systemd
sudo systemctl start integrad
```

---

## Security Considerations

- **DO NOT** use testnet keys on mainnet
- Store keys securely using hardware wallets or HSMs
- Enable firewall rules to restrict access
- Keep node software updated
- Monitor validator uptime to avoid slashing

---

## Support

- **Documentation:** https://docs.integralayer.com
- **Discord:** https://discord.gg/integralayer
- **Telegram:** https://t.me/integralayer
- **GitHub:** https://github.com/integralayer

---

*Last Updated: January 22, 2026*
