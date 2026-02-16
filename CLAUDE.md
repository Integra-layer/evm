# Cosmos EVM - Integra Network Fork

Cosmos EVM adds full EVM compatibility to Cosmos SDK chains. This repo contains generic `evmd` example + Integra Network implementation.

## Critical Context

**Pre-v1.0 Software**: Breaking changes expected. Audits in progress (see `docs/audit-*.md`).

**License**: Apache 2.0 (fork of evmOS, maintained by Cosmos Labs)

**Origin**: [github.com/cosmos/evm](https://github.com/cosmos/evm)

## Stack

- Go 1.25.5 (CGO REQUIRED for builds)
- Cosmos SDK v0.54.0-rc.1
- CometBFT v0.39.0-beta.2
- IBC-Go v10.0.0-beta.0
- Geth v1.16.7 (Cosmos fork, NOT standard go-ethereum)

## Two Reference Chains

### 1. evmd (Generic Example)
- Chain ID: 262144
- Token: atest
- Location: `/evmd/`
- App: `/evmd/app.go` (1109 lines)

### 2. Integra Network
- Mainnet Chain ID: integra-1 (Bech32 prefix: integra)
- Testnet Chain ID: integra-testnet-1
- EVM Chain ID (Mainnet): **26217** (`0x6669`)
- EVM Chain ID (Testnet): **26218** (`0x666A`)
- Token: **IRL** (base denom: **airl**)
- Location: `/integra/`
- App: `/integra/app.go` (1113 lines)
- Config: `/integra/config/` (app.toml, config.toml templates)

**CRITICAL GOTCHA**: Token is IRL/airl, NOT ILR/ailr. Code comment at line 5 of `integra/app.go` has legacy "ILR" reference.

**CRITICAL GOTCHA #2**: Default EVM chain ID after `intgd init` is 262144 (WRONG). Must manually set to 26217 (mainnet) or 26218 (testnet) in `app.toml` under `[evm]` section.

## Architecture

### Five Custom Modules (`x/`)

1. **x/vm** - Core EVM execution
   - State management (accounts, storage, code)
   - Transaction execution (eth_sendTransaction, eth_call)
   - Gas metering & custom opcodes
   - Hooks for pre/post-execution

2. **x/erc20** - Single Token Representation v2
   - IBC <-> ERC-20 bridge
   - Automatic token pair registration
   - Native Cosmos coins accessible from Solidity
   - Token conversion logic

3. **x/feemarket** - EIP-1559 Fee Market
   - Dynamic base fee calculation
   - Block gas target & elasticity
   - Fee market params (min gas price, elasticity multiplier)

4. **x/precisebank** - Fractional Tokens
   - Sub-unit precision for tokens
   - Enables decimal operations beyond base denom

5. **x/ibc** - IBC Extensions
   - IBC transfer with callbacks
   - ICS-20 token transfer integration
   - Cross-chain EVM interactions

### Twelve Precompiles (`precompiles/`)

Stateful precompiles at addresses 0x800-0x80B:

- **0x800** - Staking (delegate, undelegate, redelegate)
- **0x801** - Distribution (withdraw rewards, set withdraw address)
- **0x802** - ICS20 (IBC token transfer from Solidity)
- **0x803** - ICS02 (IBC client operations)
- **0x804** - Bank (send, balance, supply queries)
- **0x805** - Gov (submit proposals, vote, query)
- **0x806** - Slashing (unjail, query params)
- **0x807** - Bech32 (address conversion utilities)
- **0x808** - ERC20 (token pair registration)
- **0x809** - WERC20 (wrapped ERC20 operations)
- **0x80A** - Callbacks (IBC callbacks from Solidity)
- **0x80B** - P256 (secp256r1 signature verification)

All precompiles expose Cosmos SDK functionality to Solidity smart contracts.

## Key Directories

- `/ante/` - AnteHandler (tx validation, gas deduction, EVM setup)
- `/client/` - CLI commands & queries
- `/contracts/` - Solidity test contracts
- `/crypto/` - Crypto utilities (eth_secp256k1 key handling)
- `/docs/` - Migration guides, audit findings
- `/eips/` - Custom EIP implementations
- `/encoding/` - Protobuf & Ethereum tx encoding
- `/evmd/` - Generic example chain binary
- `/integra/` - Integra Network implementation
- `/precompiles/` - Stateful precompiles (0x800-0x80B)
- `/proto/` - Protobuf definitions
- `/rpc/` - JSON-RPC server (eth, web3, net, debug namespaces)
- `/server/` - Node startup & config
- `/tests/` - Unit tests (Ginkgo/Gomega), Solidity tests (Foundry/Hardhat), system tests
- `/x/` - Custom Cosmos SDK modules

## Build & Install

```bash
# Build evmd binary (CGO required)
make build                    # Output: ./build/evmd

# Install to $GOPATH/bin
make install                  # Creates: $GOPATH/bin/evmd

# Build Linux binary
make build-linux

# Build Integra binary (if separate Makefile exists)
cd integra && make install    # Creates: intgd binary
```

**CGO Requirement**: Must have gcc/clang installed. Build fails without CGO.

## Testing

```bash
# Unit tests (Go)
make test-unit
make test-unit-cover          # Generates filtered_coverage.txt

# Solidity tests (Foundry/Hardhat)
make test-solidity

# System tests (end-to-end)
make test-system

# Fuzz testing
make test-fuzz

# Benchmarks
make benchmark
```

**Test Frameworks**:
- Go: Ginkgo/Gomega (BDD style)
- Solidity: Foundry (forge) + Hardhat

## Local Development

```bash
# Fresh local node (deletes existing data)
./local_node.sh -y

# Keep existing data
./local_node.sh -n

# Custom chain ID
CHAIN_ID=9001 ./local_node.sh -y

# Script creates:
# - ~/.evmd/ home directory
# - Test keyring with dev accounts
# - Genesis with initial balances
# - Single validator node
```

**Default Settings**:
- Chain ID: 9001
- Moniker: localtestnet
- Keyring: test (insecure, dev only)
- Key algo: eth_secp256k1
- Base fee: 10,000,000

## JSON-RPC Server

Exposes Ethereum-compatible API at `localhost:8545` (configurable in `app.toml`).

**Namespaces**:
- `eth_*` - Ethereum JSON-RPC (sendTransaction, call, getBalance, etc.)
- `web3_*` - Web3 utilities (clientVersion, sha3)
- `net_*` - Network info (version, peerCount)
- `debug_*` - Debugging (traceTransaction, traceCall)
- `personal_*` - Account management (newAccount, unlockAccount)

**Config** (`app.toml` under `[json-rpc]` section):
- Address/port bindings
- API namespaces to enable
- Timeouts for calls
- Gas caps
- Max open connections

## Entry Points

### Integra Network
- **Binary**: `intgd` (if built separately) or `evmd` from `/integra/cmd/`
- **App**: `/integra/app.go` (1113 lines)
- **Config**: `/integra/config/` (templates for app.toml, config.toml)
- **Chain params**: integra-1 chain ID, ailr denom

### Generic evmd
- **Binary**: `evmd` from `/evmd/cmd/`
- **App**: `/evmd/app.go` (1109 lines)
- **Chain params**: 262144 chain ID, atest denom

Both use identical module structure, differ only in chain-specific constants.

## Common Operations

### Initialize Node
```bash
evmd init <moniker> --chain-id 9001 --home ~/.evmd
# Or for Integra:
intgd init <moniker> --chain-id integra-1 --home ~/.integra
```

**CRITICAL**: After init, check `~/.evmd/config/app.toml` and set correct EVM chain ID (26217 for mainnet, 26218 for testnet — NOT 262144).

### Add Keys
```bash
evmd keys add <name> --keyring-backend test --algo eth_secp256k1
# Generates Ethereum-compatible key (0x... address)
```

### Start Node
```bash
evmd start --home ~/.evmd
# Starts both Tendermint consensus + JSON-RPC server
```

### Query EVM State
```bash
# Via CLI
evmd query evm code <address> --home ~/.evmd

# Via JSON-RPC (curl)
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["0x...","latest"],"id":1}' http://localhost:8545
```

## Module Interactions

### Typical Flow: IBC Token -> EVM
1. IBC transfer brings token to chain (handled by `x/ibc/transfer`)
2. Token lands in user's Cosmos account
3. User calls `x/erc20` ConvertCoin to get ERC-20 representation
4. ERC-20 token now usable in Solidity contracts via 0x808 precompile
5. Callbacks via 0x80A precompile for cross-chain responses

### Typical Flow: EVM Contract Deploy
1. User sends eth_sendTransaction via JSON-RPC
2. RPC server converts to Cosmos SDK MsgEthereumTx
3. AnteHandler validates (in `/ante/`)
4. MsgEthereumTx routed to `x/vm` module
5. `x/vm` executes via Geth EVM (in `/x/vm/keeper/state_transition.go`)
6. State changes committed to Cosmos state tree
7. Precompiles accessible during execution

## Debugging Tips

### Build Issues
- **Error: "undefined reference to..."**: CGO not enabled. Set `CGO_ENABLED=1`.
- **Error: "cannot find package"**: Run `go mod download` and `go mod tidy`.
- **RocksDB/LevelDB errors**: Add build tags: `COSMOS_BUILD_OPTIONS=rocksdb make build`.

### Runtime Issues
- **JSON-RPC not responding**: Check `app.toml` `[json-rpc]` section, ensure `enable = true`.
- **Wrong chain ID in MetaMask**: EVM chain ID != Cosmos chain ID. Set correct EVM chain ID in `app.toml`.
- **Gas estimation fails**: Check base fee in `x/feemarket` params. May need to increase min gas price.
- **Precompile call fails**: Verify precompile address (0x800-0x80B) and ABI match. Check `precompiles/<name>/precompile.go`.

### Common Gotchas
1. **Token naming**: Integra uses IRL (ailr), NOT ILR. Code comment has legacy reference.
2. **Chain ID mismatch**: Default EVM chain ID after init is 262144. Must set to 26217 (mainnet) or 26218 (testnet) in app.toml.
3. **CGO requirement**: Cannot build without CGO. Native M1/M2 Mac builds need Rosetta or cross-compile.
4. **Geth fork**: Uses Cosmos fork of go-ethereum. Standard geth packages incompatible.
5. **Keyring algo**: Must use `eth_secp256k1` for Ethereum-compatible addresses. Default `secp256k1` creates Cosmos-only keys.
6. **IBC denom format**: IBC tokens have format `ibc/{hash}`. Must register with `x/erc20` for EVM use.

## Audit Status

See `/docs/audit-comprehensive-findings.md` and `/docs/audit-round2-findings.md`.

- Round 1: 49 issues identified
- Round 2: 25 issues fixed
- Status: Ongoing audits, pre-v1.0

**Key fixes**: Reentrancy guards, state validation, gas metering, precompile security.

## Migration Guides

Located in `/docs/migrations/`:
- `v0.3.0_to_v0.4.0.md` - Initial modules refactor
- `v0.4.0_to_v0.5.0.md` - ERC-20 v2 migration
- `v0.5.0_to_v0.6.0.md` - Latest breaking changes
- `v0.4.0_erc20_precompiles_migration.md` - ERC-20 precompile changes

**Breaking changes expected** until v1.0 release.

## Extension Points

### Custom Precompiles
Add new precompiles by:
1. Implement `PrecompiledContract` interface in `/precompiles/`
2. Register in app.go: `evmKeeper.WithPrecompiles(...)`
3. Assign address in 0x800+ range
4. Generate ABI for Solidity interface

### Custom Opcodes
Modify EVM behavior in `/x/vm/`:
1. Add opcode in `config.go` (ExtraOpcodes)
2. Implement execution in `state_transition.go`
3. Update gas costs in `gas.go`

### Custom Ante Handlers
Chain ante decorators in app.go:
1. Create decorator implementing `AnteDecorator` interface
2. Add to ante handler chain in `NewAnteHandler()`
3. Order matters: validation -> gas deduction -> execution

## Production Checklist

Before mainnet deployment:
- [ ] Set secure keyring backend (NOT test)
- [ ] Configure proper JSON-RPC rate limiting
- [ ] Set correct EVM chain ID in app.toml (must match chainlist.org)
- [ ] Enable only required JSON-RPC namespaces
- [ ] Set gas caps to prevent DoS
- [ ] Configure proper logging (NOT debug level)
- [ ] Set up monitoring for gas usage, tx throughput
- [ ] Test IBC relayers with token conversions
- [ ] Audit all custom precompiles
- [ ] Load test JSON-RPC endpoints
- [ ] Verify chain upgrade handlers
- [ ] Set governance params (deposit, voting period)
- [ ] Configure pruning strategy

## Resources

- **Official Docs**: [evm.cosmos.network](https://evm.cosmos.network)
- **Source**: [github.com/cosmos/evm](https://github.com/cosmos/evm)
- **Discord**: [discord.com/invite/interchain](https://discord.com/invite/interchain)
- **Telegram**: [t.me/CosmosOG](https://t.me/CosmosOG)

## Quick Reference

### File Sizes
- `integra/app.go`: 1113 lines
- `evmd/app.go`: 1109 lines
- Precompiles: 171 Go files
- Total modules: 5 (vm, erc20, feemarket, precisebank, ibc)
- Total precompiles: 12 (0x800-0x80B)

### Default Ports
- Tendermint RPC: 26657
- JSON-RPC: 8545
- WS JSON-RPC: 8546
- gRPC: 9090
- gRPC-web: 9091
- API: 1317

### Environment Variables
- `CHAIN_ID` - Override default chain ID
- `CGO_ENABLED` - Must be 1 for builds
- `COSMOS_BUILD_OPTIONS` - Build flags (rocksdb, cleveldb, nostrip, staticlink)

---

**Last Updated**: 2026-02-12
**Maintainer**: Cosmos Labs
**Contributors**: B-Harvest, Mantra, Integra Network
