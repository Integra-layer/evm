# Integra Testnet Configuration

> **Network:** Integra Testnet (Ormos)
> **Chain ID:** `integra-testnet-1`
> **Status:** Testing Environment

---

## Network Overview

Ormos Testnet is the testing environment for the Integra Network. Use this network for development, testing, and experimentation. **Tokens on testnet have no real value.**

---

## Quick Reference

| Parameter | Value |
|-----------|-------|
| **Chain ID** | `integra-testnet-1` |
| **Network Name** | Integra Testnet |
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
| **EVM JSON-RPC** | `https://ormos.integralayer.com/rpc` |
| **Cosmos RPC** | `https://ormos.integralayer.com/cometbft` |
| **REST API** | `https://ormos.integralayer.com/rest` |
| **EVM WebSocket** | `wss://ormos.integralayer.com/ws` |
| **Cosmos WebSocket** | `wss://ormos.integralayer.com/cometbft/websocket` |
| **Block Explorer** | `https://testnet.blockscout.integralayer.com` |
| **Faucet** | `https://faucet.integralayer.com` |

---

## EVM Configuration

| Parameter | Value |
|-----------|-------|
| **EVM Chain ID** | `26218` |
| **Currency Symbol** | IRL |
| **Block Explorer** | https://testnet.blockscout.integralayer.com |

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
  "rpcUrls": ["https://ormos.integralayer.com/rpc"],
  "blockExplorerUrls": ["https://testnet.blockscout.integralayer.com"]
}
```

### Hardhat Configuration

```javascript
module.exports = {
  networks: {
    ormos: {
      url: "https://ormos.integralayer.com/rpc",
      chainId: 26218,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

### Foundry Configuration

```toml
[rpc_endpoints]
ormos = "https://ormos.integralayer.com/rpc"

[etherscan]
ormos = { key = "", chain = 26218, url = "https://testnet.blockscout.integralayer.com/api" }
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
| **Bond Denom** | `airl` |

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
export CHAIN_ID="integra-testnet-1"

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
| Chain ID | `integra-testnet-1` | `integra-1` |
| Token Symbol | IRL | IRL |
| Base Denom | `airl` | `airl` |
| EVM Chain ID | 26218 | 26217 |
| Address Prefix | `integra` | `integra` |
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
