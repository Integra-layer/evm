# Integra Network Configuration

> **Version:** 1.1  
> **Date:** January 22, 2026

---

## Network Overview

Integra operates two networks for different purposes:

| Network | Purpose | Status |
|---------|---------|--------|
| **Integra Mainnet** | Production network with real value | Active |
| **Ormos Testnet** | Development and testing environment | Active |

---

## Quick Comparison

| Parameter | Mainnet (Integra) | Testnet (Ormos) |
|-----------|-------------------|-----------------|
| **Chain ID** | `integra-1` | `integra-testnet-1` |
| **EVM Chain ID** | `26217` (0x6669) | `26218` (0x666A) |
| **Network Name** | Integra | Ormos |
| **Token Name** | Integra | IRL |
| **Token Symbol** | IRL | IRL |
| **Base Denom** | `airl` | `airl` |
| **Address Prefix** | `integra` | `integra` |
| **Decimals** | 18 | 18 |
| **Description** | "The native token of Integra" | "The native token of Integra Testnet" |

---

## RPC Endpoints

### Mainnet

| Service | URL |
|---------|-----|
| EVM RPC | `https://evm.integralayer.com` |
| Cosmos RPC | `https://rpc.integralayer.com` |
| REST API | `https://api.integralayer.com` |
| gRPC | `grpc.integralayer.com:9090` |
| WebSocket | `wss://rpc.integralayer.com/websocket` |
| Explorer | `https://explorer.integralayer.com` |

### Testnet

| Service | URL |
|---------|-----|
| EVM RPC | `https://ormos.integralayer.com/rpc` |
| Cosmos RPC | `https://ormos.integralayer.com/cometbft` |
| REST API | `https://ormos.integralayer.com/rest` |
| EVM WebSocket | `wss://ormos.integralayer.com/ws` |
| Cosmos WebSocket | `wss://ormos.integralayer.com/cometbft/websocket` |
| Explorer | `https://testnet.explorer.integralayer.com` |
| Blockscout (EVM) | `https://testnet.blockscout.integralayer.com` |
| Faucet | `https://faucet.integralayer.com` |

---

## Token Economics Comparison

| Parameter | Mainnet | Testnet |
|-----------|---------|---------|
| **Total Supply** | 100,000,000,000 IRL | 100,000,000,000 oIRL |
| **Inflation Rate** | 3% (fixed) | 13% (dynamic) |
| **Inflation Min** | 3% | 7% |
| **Inflation Max** | 3% | 20% |
| **Target Bonded** | 0% | 67% |
| **Community Tax** | **0%** | **0%** |

---

## Staking Parameters Comparison

| Parameter | Mainnet | Testnet |
|-----------|---------|---------|
| **Unbonding Period** | 21 days | 1 day |
| **Max Validators** | 100 | 100 |
| **Min Commission** | 0% | 0% |
| **Bond Denom** | `airl` | `airl` |

---

## Governance Parameters Comparison

| Parameter | Mainnet | Testnet |
|-----------|---------|---------|
| **Min Deposit** | 100,000,000 IRL | 1,000 oIRL |
| **Deposit Period** | **7 days** | 1 hour |
| **Voting Period** | **7 days** | 1 hour |
| **Expedited Voting** | 3 days | 30 minutes |
| **Quorum** | 33.4% | 33.4% |
| **Pass Threshold** | 51% | 51% |
| **Veto Threshold** | 33.4% | 33.4% |

---

## Transaction Fee Comparison

### Fee Calculation (Based on $1B Valuation)

| Parameter | Mainnet | Testnet |
|-----------|---------|---------|
| **Base Fee** | 23,809,523,809,524 airl/gas | 23,809,523,809,524 aoirl/gas |
| **Simple Transfer (21K gas)** | **0.5 IRL** (~$0.005) | **0.5 oIRL** |
| **Token Transfer (65K gas)** | ~1.55 IRL | ~1.55 oIRL |

### Fee Calculation Breakdown

```
At $1 Billion Valuation:
- Total Supply: 100 Billion IRL
- Price per IRL: $0.01
- Target TX Fee: 0.5 IRL = $0.005 (half a cent)

Base Fee = (0.5 IRL × 10^18 airl) / 21,000 gas
         = 500,000,000,000,000,000 / 21,000
         = 23,809,523,809,524 airl/gas
```

---

## EVM Configuration

### Mainnet

```javascript
// ethers.js / viem
const mainnetConfig = {
  chainId: 26217,
  name: 'Integra Mainnet',
  network: 'integra',
  rpcUrls: {
    default: { http: ['https://evm.integralayer.com'] },
    public: { http: ['https://evm.integralayer.com'] }
  },
  nativeCurrency: {
    name: 'Integra',
    symbol: 'IRL',
    decimals: 18
  },
  blockExplorers: {
    default: { name: 'Integra Explorer', url: 'https://explorer.integralayer.com' }
  }
};
```

### Testnet

```javascript
// ethers.js / viem
const testnetConfig = {
  chainId: 26218,
  name: 'Integra Testnet',
  network: 'integra-testnet',
  rpcUrls: {
    default: { http: ['https://ormos.integralayer.com/rpc'] },
    public: { http: ['https://ormos.integralayer.com/rpc'] }
  },
  nativeCurrency: {
    name: 'IRL',
    symbol: 'IRL',
    decimals: 18
  },
  blockExplorers: {
    default: { name: 'Ormos Explorer', url: 'https://testnet.blockscout.integralayer.com' }
  }
};
```

---

## Wallet Configuration

### MetaMask - Mainnet

| Field | Value |
|-------|-------|
| Network Name | Integra Mainnet |
| RPC URL | https://evm.integralayer.com |
| Chain ID | 26217 |
| Currency Symbol | IRL |
| Block Explorer | https://explorer.integralayer.com |

### MetaMask - Testnet

| Field | Value |
|-------|-------|
| Network Name | Integra Testnet |
| RPC URL | https://ormos.integralayer.com/rpc |
| Chain ID | 26218 |
| Currency Symbol | IRL |
| Block Explorer | https://testnet.blockscout.integralayer.com |

### Keplr - Mainnet

```javascript
const keplrMainnetConfig = {
  chainId: "integra-1",
  chainName: "Integra Mainnet",
  rpc: "https://rpc.integralayer.com:26657",
  rest: "https://api.integralayer.com",
  bip44: { coinType: 60 },
  bech32Config: {
    bech32PrefixAccAddr: "integra",
    bech32PrefixAccPub: "integrapub",
    bech32PrefixValAddr: "integravaloper",
    bech32PrefixValPub: "integravaloperpub",
    bech32PrefixConsAddr: "integravalcons",
    bech32PrefixConsPub: "integravalconspub"
  },
  currencies: [{
    coinDenom: "IRL",
    coinMinimalDenom: "airl",
    coinDecimals: 18
  }],
  feeCurrencies: [{
    coinDenom: "IRL",
    coinMinimalDenom: "airl",
    coinDecimals: 18,
    gasPriceStep: { low: 0.01, average: 0.025, high: 0.04 }
  }],
  stakeCurrency: {
    coinDenom: "IRL",
    coinMinimalDenom: "airl",
    coinDecimals: 18
  }
};
```

### Keplr - Testnet

```javascript
const keplrTestnetConfig = {
  chainId: "integra-testnet-1",
  chainName: "Integra Testnet",
  rpc: "https://ormos.integralayer.com/rpc:26657",
  rest: "https://ormos.integralayer.com/rest",
  bip44: { coinType: 60 },
  bech32Config: {
    bech32PrefixAccAddr: "integra",
    bech32PrefixAccPub: "integrapub",
    bech32PrefixValAddr: "integravaloper",
    bech32PrefixValPub: "integravaloperpub",
    bech32PrefixConsAddr: "integravalcons",
    bech32PrefixConsPub: "integravalconspub"
  },
  currencies: [{
    coinDenom: "IRL",
    coinMinimalDenom: "airl",
    coinDecimals: 18
  }],
  feeCurrencies: [{
    coinDenom: "IRL",
    coinMinimalDenom: "airl",
    coinDecimals: 18,
    gasPriceStep: { low: 0.01, average: 0.025, high: 0.04 }
  }],
  stakeCurrency: {
    coinDenom: "IRL",
    coinMinimalDenom: "airl",
    coinDecimals: 18
  }
};
```

---

## Genesis Accounts

### Mainnet Treasury

| Format | Address |
|--------|---------|
| Bech32 | `integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw` |
| EVM | `0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4` |
| Balance | 100,000,000,000 IRL |

### Testnet Treasury

| Format | Address |
|--------|---------|
| Bech32 | `ormos1khs68tk2jatw0jthrtkfpfm7jckjsd05zfxwpy` |
| EVM | `0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4` |
| Balance | 100,000,000,000 oIRL |

---

## Address Conversion

Both networks use the same underlying EVM address but with different bech32 prefixes:

```
EVM Address:    0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4
                              ↓
Mainnet:        integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw
Testnet:        ormos1khs68tk2jatw0jthrtkfpfm7jckjsd05zfxwpy
```

---

## Slashing Parameters (Same for Both)

| Parameter | Value |
|-----------|-------|
| **Signed Blocks Window** | 100 |
| **Min Signed Per Window** | 50% |
| **Downtime Jail Duration** | 10 minutes |
| **Double Sign Slash** | 5% |
| **Downtime Slash** | 1% |

---

## Module Configuration (Same for Both)

| Module | Status |
|--------|--------|
| **EVM** | Enabled (Permissionless) |
| **ERC-20** | Enabled |
| **IBC** | Enabled (All clients: `*`) |
| **Authz** | Enabled |
| **Feegrant** | Enabled |
| **Governance** | Enabled |
| **Staking** | Enabled |
| **Distribution** | Enabled |
| **Mint** | Enabled |
| **Vesting** | Enabled |

---

## File Structure

```
deployment/
├── NETWORK_CONFIG.md          # This file
├── mainnet/
│   ├── README.md              # Mainnet documentation
│   └── genesis.json           # Mainnet genesis file
└── testnet/
    ├── README.md              # Testnet documentation
    └── genesis.json           # Testnet genesis file
```

---

## Key Changes from Meeting (Jan 22, 2026)

| Item | Previous | Updated |
|------|----------|---------|
| Base Denom | `ailr` (typo, fixed) | `airl` |
| Description | "...Real World Asset Layer 1" | "The native token of Integra" |
| Deposit Period | 2 days | **7 days** |
| Voting Period | 2 days | **7 days** |
| Community Tax | 2% | **0%** |
| TX Fee (Simple) | ~0.000021 IRL | **0.5 IRL** |
| Base Fee | 1 gwei | ~24 trillion airl/gas |

---

## Security Notes

| ⚠️ Warning |
|------------|
| Never use mainnet private keys on testnet |
| Never use testnet private keys on mainnet |
| Testnet tokens have no real value |
| Mainnet transactions are irreversible |

---

## Support Channels

| Channel | URL |
|---------|-----|
| Documentation | https://docs.integralayer.com |
| Discord | https://discord.gg/integralayer |
| Telegram | https://t.me/integralayer |
| GitHub | https://github.com/integralayer |
| Twitter | https://twitter.com/integralayer |

---

*Last Updated: January 22, 2026*
