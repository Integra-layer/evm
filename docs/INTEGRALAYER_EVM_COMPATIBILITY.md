# Integralayer EVM Compatibility Documentation

> **Last Updated:** January 16, 2026  
> **Document Version:** 1.0

---

## Executive Summary

This document provides comprehensive EVM compatibility information for Integralayer networks. **CRITICAL FINDING:** The Pre-Production Mainnet and Testnet have different EVM versions:

| Network | EVM Version | MCOPY (0x5E) Support | Recommended Solidity |
|---------|-------------|---------------------|---------------------|
| **Pre-Production Mainnet** | Cancun | ✅ Supported | Any version |
| **Testnet** | Shanghai | ❌ NOT Supported | ≤ 0.8.23 |

---

## Table of Contents

1. [Network Configuration](#1-network-configuration)
2. [EVM Version Compatibility](#2-evm-version-compatibility)
3. [Opcode Support Matrix](#3-opcode-support-matrix)
4. [Solidity Compiler Settings](#4-solidity-compiler-settings)
5. [JavaScript Library Compatibility](#5-javascript-library-compatibility)
6. [Common Errors and Solutions](#6-common-errors-and-solutions)
7. [RPC Endpoint Reference](#7-rpc-endpoint-reference)
8. [Block Explorer Issues](#8-block-explorer-issues)
9. [Recommended Development Workflow](#9-recommended-development-workflow)
10. [FAQ](#10-faq)

---

## 1. Network Configuration

### Pre-Production Mainnet

| Parameter | Value |
|-----------|-------|
| **Network Name** | Integralayer Pre-Production |
| **Chain ID (EVM)** | `26217` (`0x6669`) |
| **Chain ID (Cosmos)** | `integra-1` |
| **EVM RPC URL** | `https://evm.integralayer.com` |
| **Cosmos RPC URL** | `https://rpc.integralayer.com` |
| **REST API URL** | `https://api.integralayer.com` |
| **WebSocket URL** | `wss://ws.integralayer.com` |
| **Block Explorer** | `https://explorer.integralayer.com` |
| **Native Token** | IRL (18 decimals) |
| **Base Denom** | `ailr` (atto-IRL) |
| **Current Block** | ~164,778 (as of testing) |
| **EVM Version** | **Cancun** |

### Testnet (Legacy)

| Parameter | Value |
|-----------|-------|
| **Network Name** | Integralayer Testnet |
| **Chain ID (EVM)** | `1341` (`0x53D`) |
| **Chain ID (Cosmos)** | `integratestnet_1341-1` |
| **EVM RPC URL** | `https://testnet-rpc.integralayer.com` |
| **Current Block** | ~1,368,138 (as of testing) |
| **EVM Version** | **Shanghai** ⚠️ |

> ⚠️ **WARNING:** The testnet is running an OLDER EVM version than Pre-Production. Code that works on Pre-Production may FAIL on Testnet!

---

## 2. EVM Version Compatibility

### Ethereum Hardfork Timeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ETHEREUM HARDFORK TIMELINE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Paris (The Merge)  ──▶  Shanghai  ──▶  Cancun  ──▶  Prague         │
│  Sep 2022              Apr 2023       Mar 2024      TBD              │
│                                                                      │
│  Integralayer Testnet: █████████████                                │
│  (Shanghai - Pre-Cancun)                                            │
│                                                                      │
│  Integralayer Pre-Prod:█████████████████████████                    │
│  (Cancun - Full Support)                                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Feature Availability by Network

| Feature | Pre-Production | Testnet | EIP |
|---------|----------------|---------|-----|
| PUSH0 opcode | ✅ | ✅ | EIP-3855 |
| Warm COINBASE | ✅ | ✅ | EIP-3651 |
| MCOPY opcode | ✅ | ❌ | EIP-5656 |
| Transient Storage (TSTORE/TLOAD) | ✅ | ❌ | EIP-1153 |
| Blob Transactions (Type 3) | ✅ | ❌ | EIP-4844 |
| BLOBHASH opcode | ✅ | ❌ | EIP-4844 |
| BLOBBASEFEE opcode | ✅ | ❌ | EIP-7516 |
| Self-destruct restriction | ✅ | ❌ | EIP-6780 |

---

## 3. Opcode Support Matrix

### New Opcodes in Cancun (NOT available on Testnet)

| Opcode | Hex | Description | Gas Cost |
|--------|-----|-------------|----------|
| `TLOAD` | `0x5C` | Load from transient storage | 100 |
| `TSTORE` | `0x5D` | Store to transient storage | 100 |
| `MCOPY` | `0x5E` | Memory copy | 3 + 3*words + mem expansion |
| `BLOBHASH` | `0x49` | Get blob versioned hash | 3 |
| `BLOBBASEFEE` | `0x4A` | Get blob base fee | 2 |

### Verified Test Results

```bash
# MCOPY opcode test (0x5E)

# Pre-Production (evm.integralayer.com):
curl -X POST https://evm.integralayer.com \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"data":"0x60206000600060005e00"},"latest"],"id":1}'
# Result: {"result":"0x"}  ✅ SUCCESS

# Testnet (testnet-rpc.integralayer.com):  
curl -X POST https://testnet-rpc.integralayer.com \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"data":"0x60206000600060005e00"},"latest"],"id":1}'
# Result: {"error":{"code":-32000,"message":"invalid opcode: opcode 0x5e not defined"}}  ❌ FAIL
```

---

## 4. Solidity Compiler Settings

### The Problem

Starting with **Solidity 0.8.24**, the compiler defaults to the **Cancun** EVM version, which generates bytecode using new opcodes like `MCOPY (0x5E)`. This bytecode will fail on networks that don't support Cancun.

### Solution: Specify `evmVersion`

#### Hardhat Configuration

```javascript
// hardhat.config.js
module.exports = {
  solidity: {
    version: "0.8.24",  // or any version
    settings: {
      evmVersion: "shanghai",  // ⬅️ ADD THIS for Testnet compatibility
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    integraTestnet: {
      url: "https://testnet-rpc.integralayer.com",
      chainId: 1341,
      accounts: [process.env.PRIVATE_KEY],
    },
    integraPreProd: {
      url: "https://evm.integralayer.com",
      chainId: 26217,
      accounts: [process.env.PRIVATE_KEY],
      // No evmVersion override needed - Cancun is supported
    },
  },
};
```

#### Foundry Configuration

```toml
# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

# For Testnet compatibility:
evm_version = "shanghai"

[profile.testnet]
evm_version = "shanghai"

[profile.preprod]
evm_version = "cancun"

[rpc_endpoints]
integra_testnet = "https://testnet-rpc.integralayer.com"
integra_preprod = "https://evm.integralayer.com"
```

#### Remix IDE

1. Go to **Solidity Compiler** tab
2. Click **Advanced Configuration**
3. Set **EVM Version** to `shanghai`

#### solc CLI

```bash
solc --evm-version shanghai MyContract.sol
```

### Solidity Version Compatibility Chart

| Solidity Version | Default evmVersion | Works on Testnet? | Works on Pre-Prod? |
|------------------|-------------------|-------------------|-------------------|
| 0.8.19 | paris | ✅ Yes | ✅ Yes |
| 0.8.20 - 0.8.23 | shanghai | ✅ Yes | ✅ Yes |
| **0.8.24+** | **cancun** | ❌ **NO** (without override) | ✅ Yes |

### Quick Fix: Use Older Solidity

If you can't modify your config, use Solidity ≤ 0.8.23:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;  // ⬅️ Use this version for maximum compatibility
```

---

## 5. JavaScript Library Compatibility

### viem

The `opcode 0x5e not defined` error often comes from viem's internal bytecode operations.

```typescript
// viem config for Testnet
import { defineChain } from 'viem';

export const integraTestnet = defineChain({
  id: 1341,
  name: 'Integralayer Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'IRL',
    symbol: 'IRL',
  },
  rpcUrls: {
    default: { http: ['https://testnet-rpc.integralayer.com'] },
  },
  blockExplorers: {
    default: { name: 'Explorer', url: 'https://explorer.integralayer.com' },
  },
});

// Pre-Production config
export const integraPreProd = defineChain({
  id: 26217,
  name: 'Integralayer Pre-Production',
  nativeCurrency: {
    decimals: 18,
    name: 'IRL',
    symbol: 'IRL',
  },
  rpcUrls: {
    default: { http: ['https://evm.integralayer.com'] },
  },
  blockExplorers: {
    default: { name: 'Explorer', url: 'https://explorer.integralayer.com' },
  },
});
```

**If you're getting MCOPY errors with viem:**
- Ensure your contract is compiled with `evmVersion: "shanghai"`
- Use Pre-Production network instead of Testnet
- Check if you're using latest viem/wagmi which may use Cancun bytecode internally

### ethers.js

```typescript
import { ethers } from 'ethers';

// Testnet
const testnetProvider = new ethers.JsonRpcProvider(
  'https://testnet-rpc.integralayer.com',
  { chainId: 1341, name: 'integra-testnet' }
);

// Pre-Production
const preprodProvider = new ethers.JsonRpcProvider(
  'https://evm.integralayer.com',
  { chainId: 26217, name: 'integra-preprod' }
);
```

### web3.js

```typescript
import Web3 from 'web3';

// Testnet
const web3Testnet = new Web3('https://testnet-rpc.integralayer.com');

// Pre-Production  
const web3PreProd = new Web3('https://evm.integralayer.com');
```

---

## 6. Common Errors and Solutions

### Error: `invalid opcode: opcode 0x5e not defined`

**Cause:** Your contract or library is using the `MCOPY` opcode (Cancun feature) but you're connected to Testnet (Shanghai).

**Solutions:**
1. **Use Pre-Production** instead of Testnet
2. **Recompile** with `evmVersion: "shanghai"`
3. **Downgrade Solidity** to ≤ 0.8.23

### Error: `invalid opcode: opcode 0x5c not defined` or `0x5d`

**Cause:** Contract uses `TSTORE`/`TLOAD` (transient storage, EIP-1153).

**Solutions:** Same as above.

### Error: Transaction not visible on Explorer

**Causes:**
1. Using EVM transaction hash (0x...) instead of Cosmos hash
2. Explorer indexing delay
3. Transaction on different network

**Solution:** 
- Use the Cosmos hash (uppercase, no 0x prefix) in the explorer URL
- Wait for indexing to complete
- Verify you're on the correct network

### Error: Cannot search by EVM transaction hash

**Known Issue:** The explorer currently only supports Cosmos transaction hashes.

**Workaround:** Convert EVM hash to Cosmos hash or use the transaction details from your wallet/dApp.

---

## 7. RPC Endpoint Reference

### Pre-Production Mainnet Endpoints

| Service | URL | Protocol |
|---------|-----|----------|
| EVM JSON-RPC | `https://evm.integralayer.com` | HTTPS |
| EVM WebSocket | `wss://ws.integralayer.com` | WSS |
| Cosmos RPC | `https://rpc.integralayer.com` | HTTPS |
| Cosmos REST | `https://api.integralayer.com` | HTTPS |
| Cosmos gRPC | `grpc.integralayer.com:9090` | gRPC |

### Testnet Endpoints

| Service | URL | Protocol |
|---------|-----|----------|
| EVM JSON-RPC | `https://testnet-rpc.integralayer.com` | HTTPS |

> ⚠️ **Note:** Additional testnet endpoints may not be documented or available.

### RPC Method Support

Both networks support standard Ethereum JSON-RPC methods:

```
eth_chainId ✅
eth_blockNumber ✅  
eth_getBalance ✅
eth_call ✅
eth_sendRawTransaction ✅
eth_getTransactionByHash ✅
eth_getTransactionReceipt ✅
eth_getLogs ✅
eth_estimateGas ✅
eth_gasPrice ✅
web3_clientVersion ✅
net_version ✅
```

---

## 8. Block Explorer Issues

### Known Limitations

| Issue | Status | Workaround |
|-------|--------|------------|
| EVM hash search not working | 🟡 In Progress | Use Cosmos hash format |
| From/To addresses show N/A | 🟡 In Progress | View transaction details page |
| Account transactions not indexed by EVM address | ⚠️ Limitation | Check main transactions page |
| Search box on home page | 🟡 In Progress | Navigate directly to URLs |

### How to View Transactions

1. **From your wallet/dApp:** Get the transaction hash
2. **Convert to Cosmos format:** Remove `0x` prefix, uppercase
3. **Navigate to:** `https://explorer.integralayer.com/transactions/YOUR_HASH`

---

## 9. Recommended Development Workflow

### For Maximum Compatibility

```
┌─────────────────────────────────────────────────────────────────┐
│                   RECOMMENDED WORKFLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Develop locally with Hardhat/Foundry                        │
│     └─ Use evmVersion: "shanghai" for compatibility             │
│                                                                  │
│  2. Test on Pre-Production (NOT Testnet)                        │
│     └─ Get test tokens from Faucet                              │
│     └─ URL: https://explorer.integralayer.com/faucet            │
│                                                                  │
│  3. Deploy to Pre-Production                                    │
│     └─ This IS the production-equivalent environment            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Sample Project Setup

```bash
# Initialize project
mkdir my-integra-project && cd my-integra-project
npm init -y

# Install dependencies
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox dotenv

# Initialize Hardhat
npx hardhat init

# Create .env file
echo "PRIVATE_KEY=your_private_key_here" > .env
```

### Example Contract Deployment

```typescript
// scripts/deploy.ts
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  
  const MyContract = await ethers.getContractFactory("MyContract");
  const contract = await MyContract.deploy();
  await contract.waitForDeployment();
  
  console.log("Contract deployed to:", await contract.getAddress());
}

main().catch(console.error);
```

```bash
# Deploy to Pre-Production
npx hardhat run scripts/deploy.ts --network integraPreProd
```

---

## 10. FAQ

### Q: Why does my contract fail on Testnet but work on Pre-Production?

**A:** The Testnet runs Shanghai EVM (pre-Cancun), while Pre-Production runs Cancun. If your contract uses new Cancun opcodes (MCOPY, TSTORE, TLOAD), it will fail on Testnet.

### Q: Which network should I use for testing?

**A:** Use **Pre-Production Mainnet** (`evm.integralayer.com`). The Testnet has an older EVM version and is not recommended for new development.

### Q: How do I get test tokens?

**A:** Visit the faucet at `https://explorer.integralayer.com/faucet` and enter your wallet address.

### Q: Why can't I search by 0x transaction hash?

**A:** The explorer currently uses Cosmos transaction format. Remove the `0x` prefix and uppercase the hash.

### Q: What Solidity version should I use?

**A:** 
- For Pre-Production only: Any version
- For Testnet compatibility: Solidity ≤ 0.8.23 OR use `evmVersion: "shanghai"`

### Q: Is the Testnet going to be upgraded?

**A:** Contact the Integralayer team for the roadmap. For now, use Pre-Production for development.

---

## Support

- **Documentation:** https://explorer.integralayer.com/developers
- **Explorer:** https://explorer.integralayer.com
- **Faucet:** https://explorer.integralayer.com/faucet

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial compatibility documentation |

---

*This document is maintained by the Integralayer team. For corrections or updates, please open an issue or contact the team.*
