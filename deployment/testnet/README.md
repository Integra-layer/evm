# Ormos Testnet Configuration

> **Network:** Ormos Testnet  
> **Chain ID:** `ormos-1`  
> **Status:** Testing Environment

---

## Network Overview

Ormos Testnet is the testing environment for the Integra Network. Use this network for development, testing, and experimentation. **Tokens on testnet have no real value.**

---

## Quick Reference

| Parameter | Value |
|-----------|-------|
| **Chain ID** | `ormos-1` |
| **Network Name** | Ormos |
| **Native Token** | oIRL |
| **Token Symbol** | oIRL |
| **Decimals** | 18 |
| **Base Denom** | `aoirl` |
| **Address Prefix** | `ormos` |
| **Valoper Prefix** | `ormosvaloper` |

---

## RPC Endpoints

| Service | URL |
|---------|-----|
| **EVM JSON-RPC** | `https://testnet-rpc.integralayer.com` |
| **Cosmos RPC** | `https://testnet-rpc.integralayer.com:26657` |
| **REST API** | `https://testnet-api.integralayer.com` |
| **gRPC** | `testnet-grpc.integralayer.com:9090` |
| **WebSocket** | `wss://testnet-rpc.integralayer.com/websocket` |
| **Block Explorer** | `https://testnet-explorer.integralayer.com` |
| **Faucet** | `https://faucet.integralayer.com` |

---

## EVM Configuration

| Parameter | Value |
|-----------|-------|
| **EVM Chain ID** | `52431` |
| **Currency Symbol** | oIRL |
| **Block Explorer** | https://testnet-explorer.integralayer.com |

### MetaMask Configuration

```json
{
  "chainId": "0xCCEF",
  "chainName": "Ormos Testnet",
  "nativeCurrency": {
    "name": "Ormos IRL",
    "symbol": "oIRL",
    "decimals": 18
  },
  "rpcUrls": ["https://testnet-rpc.integralayer.com"],
  "blockExplorerUrls": ["https://testnet-explorer.integralayer.com"]
}
```

### Hardhat Configuration

```javascript
module.exports = {
  networks: {
    ormos: {
      url: "https://testnet-rpc.integralayer.com",
      chainId: 52431,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

### Foundry Configuration

```toml
[rpc_endpoints]
ormos = "https://testnet-rpc.integralayer.com"

[etherscan]
ormos = { key = "", chain = 52431, url = "https://testnet-explorer.integralayer.com/api" }
```

---

## Faucet

Get testnet tokens from the faucet:

**URL:** https://faucet.integralayer.com

**Limits:**
- 10 oIRL per request
- 1 request per hour per address

**API:**
```bash
curl -X POST https://faucet.integralayer.com/api/faucet \
  -H "Content-Type: application/json" \
  -d '{"address": "0xYourAddress"}'
```

---

## Token Economics (Testnet)

| Parameter | Value |
|-----------|-------|
| **Total Supply** | 100,000,000,000 oIRL |
| **Inflation Rate** | 13% (dynamic) |
| **Inflation Min** | 7% |
| **Inflation Max** | 20% |
| **Target Bonded** | 67% |
| **Community Tax** | 2% |

> **Note:** Testnet uses dynamic inflation (Cosmos default) for testing purposes.

---

## Staking Parameters (Testnet)

| Parameter | Value |
|-----------|-------|
| **Unbonding Period** | 1 day (86400s) |
| **Max Validators** | 100 |
| **Min Commission** | 0% |
| **Bond Denom** | `aoirl` |

> **Note:** Shorter unbonding period for faster testing cycles.

---

## Governance Parameters (Testnet)

| Parameter | Value |
|-----------|-------|
| **Min Deposit** | 1,000 oIRL |
| **Deposit Period** | 1 hour |
| **Voting Period** | 1 hour |
| **Quorum** | 33.4% |
| **Pass Threshold** | 51% |
| **Veto Threshold** | 33.4% |

> **Note:** Faster governance cycles for testing.

---

## Genesis Accounts

| Address | Purpose | Balance |
|---------|---------|---------|
| `ormos1khs68tk2jatw0jthrtkfpfm7jckjsd05zfxwpy` | Foundation Treasury | 100B oIRL |

### Address Formats

| Format | Address |
|--------|---------|
| Bech32 | `ormos1khs68tk2jatw0jthrtkfpfm7jckjsd05zfxwpy` |
| EVM | `0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4` |

---

## Node Requirements

### Minimum Hardware (Testnet)

| Component | Specification |
|-----------|---------------|
| **CPU** | 2 cores |
| **RAM** | 8 GB |
| **Storage** | 100 GB SSD |
| **Network** | 50 Mbps |

---

## Node Setup

### 1. Initialize Node

```bash
# Set chain ID
export CHAIN_ID="ormos-1"

# Initialize node
integrad init <moniker> --chain-id $CHAIN_ID

# Copy genesis file
cp genesis.json ~/.integra/config/genesis.json
```

### 2. Configure Seeds/Peers

```bash
# Add seeds to config.toml
seeds="<testnet_seed_node_id>@<testnet_seed_ip>:26656"
sed -i "s/^seeds =.*/seeds = \"$seeds\"/" ~/.integra/config/config.toml
```

### 3. Start Node

```bash
# Start node
integrad start
```

---

## Testnet vs Mainnet Differences

| Parameter | Testnet (Ormos) | Mainnet (Integra) |
|-----------|-----------------|-------------------|
| Chain ID | `ormos-1` | `integra-1` |
| Token Symbol | oIRL | IRL |
| Base Denom | `aoirl` | `ailr` |
| EVM Chain ID | 52431 | 52430 |
| Address Prefix | `ormos` | `integra` |
| Unbonding | 1 day | 21 days |
| Governance Min Deposit | 1,000 oIRL | 100,000,000 IRL |
| Governance Voting | 1 hour | 2 days |
| Inflation | Dynamic (7-20%) | Fixed (3%) |

---

## Testing Guidelines

1. **DO NOT** use mainnet keys on testnet
2. Test all functionality before deploying to mainnet
3. Testnet may be reset periodically
4. Report bugs and issues on GitHub

---

## Support

- **Documentation:** https://docs.integralayer.com
- **Discord:** https://discord.gg/integralayer
- **Telegram:** https://t.me/integralayer
- **GitHub Issues:** https://github.com/integralayer/issues

---

*Last Updated: January 22, 2026*
