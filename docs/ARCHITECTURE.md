# Architecture — Cosmos EVM (Integra Network Fork)

> **Last Updated:** 2026-02-12
> **Source:** [github.com/cosmos/evm](https://github.com/cosmos/evm) (upstream), [github.com/Integra-layer/evm](https://github.com/Integra-layer/evm) (fork)
> **License:** Apache 2.0

---

## 1. Overview

Cosmos EVM is a framework that adds full Ethereum Virtual Machine compatibility to Cosmos SDK-based blockchains. It enables Solidity smart contracts, Ethereum tooling (MetaMask, Hardhat, Foundry, ethers.js), and the standard Ethereum JSON-RPC API to work natively on a chain that also benefits from CometBFT consensus, IBC cross-chain communication, and the Cosmos SDK module ecosystem.

The Integra Network fork customizes this framework for the Integra chain (chain ID `integra-1`, EVM chain ID `26217`, native token **IRL** / base denom `airl`).

### Core Stack

| Component | Version | Role |
|---|---|---|
| Go | 1.25.5 | Language runtime (CGO required) |
| Cosmos SDK | v0.54.0-rc.1 | Application framework, module system, state management |
| CometBFT | v0.39.0-beta.2 | Byzantine fault-tolerant consensus engine |
| IBC-Go | v10.0.0-beta.0 | Inter-Blockchain Communication protocol |
| go-ethereum | v1.16.7 (Cosmos fork) | EVM execution engine, NOT standard go-ethereum |

### Go Workspace (Multi-Module)

The repository is structured as a Go workspace with six independent modules:

| Module | Location | Purpose |
|---|---|---|
| `github.com/cosmos/evm` | `/go.mod` | Core library: precompiles, `x/` modules, RPC, ante handlers |
| evmd | `/evmd/go.mod` | Generic example chain binary |
| integra | `/integra/go.mod` | Integra Network chain binary (`intgd`) |
| jsonrpc-simulator | `/tests/jsonrpc/simulator/go.mod` | JSON-RPC compliance test simulator |
| speedtest | `/tests/speedtest/go.mod` | Performance benchmarks |
| systemtests | `/tests/systemtests/go.mod` | End-to-end system tests |

---

## 2. System Architecture

### Dual-Module Design

The chain runs two parallel execution environments within a single consensus process:

```
                    +---------------------+
                    |      CometBFT       |  (consensus, block production)
                    +----------+----------+
                               |
                    +----------v----------+
                    |     Cosmos SDK       |  (BaseApp, module router, ABCI)
                    +----------+----------+
                               |
              +----------------+----------------+
              |                                 |
    +---------v---------+            +----------v----------+
    |   Cosmos Modules  |            |      x/vm (EVM)     |
    |  (bank, staking,  |            |  (geth execution,   |
    |   gov, slashing,  |<---------+|   StateDB, opcodes)  |
    |   distribution)   | precompiles|                      |
    +-------------------+            +----------+-----------+
                                                |
                                     +----------v----------+
                                     |   12 Precompiles    |
                                     |  (Solidity bridge   |
                                     |   to Cosmos SDK)    |
                                     +---------------------+
```

Cosmos-native transactions (staking, governance, bank sends) flow through the standard SDK message router. Ethereum transactions arrive via JSON-RPC, get wrapped as `MsgEthereumTx`, pass through a specialized EVM AnteHandler chain, and execute inside the geth VM. Precompiled contracts at fixed addresses (0x100, 0x400, 0x800-0x807) allow Solidity code to call Cosmos SDK keeper methods directly.

### Application Interface Hierarchy

```
servertypes.Application
  -> runtime.AppI
    -> TestApp           (minimal: BaseApp + core keeper providers)
      -> EvmApp          (full: all keeper providers including EVM, ERC20, feemarket)
        -> IBCApp        (adds IBCKeeperProvider for cross-chain tests)
```

Keeper provider interfaces and precompile-specific app interfaces (`BankPrecompileApp`, `StakingPrecompileApp`, `Erc20PrecompileApp`) are defined in `/interfaces.go`.

---

## 3. Cosmos SDK Modules

### 3.1 x/vm — Core EVM Execution

**Module name:** `evm` | **Store key:** `evm`

The central module. It wraps the go-ethereum EVM and maps Ethereum state onto the Cosmos KVStore.

**Key responsibilities:**
- Execute `MsgEthereumTx` (contract deployment, contract calls, ETH transfers)
- Maintain EVM state: accounts, nonces, balances, contract code, storage slots
- Manage precompile registration (static and dynamic)
- Provide `StateDB` implementation that satisfies geth's `vm.StateDB` interface over Cosmos state
- Gas metering that bridges EVM gas with Cosmos SDK gas
- Pre-installed contract support (contracts deployed at genesis)

**Msg types:** `MsgEthereumTx`, `MsgUpdateParams`, `MsgRegisterPreinstalls`

**State layout (store prefixes):**

| Prefix | Key | Value |
|---|---|---|
| `0x01` | `codeHash` | Contract bytecode |
| `0x02` | `address(20) + storageKey(32)` | Storage slot value |
| `0x03` | (singleton) | Module params |
| `0x04` | `address(20)` | Code hash for account |
| `0x05` | (singleton) | EVM coin info (denom, decimals) |

**StateDB** (`x/vm/statedb/`): Implements geth's `vm.StateDB` interface. Manages per-account state objects, journals for revert, EIP-2929 access lists, and EIP-1153 transient storage. State changes commit to the Cosmos KVStore only on successful transaction completion.

**Wrappers** (`x/vm/wrappers/`): `BankWrapper` and `FeeMarketWrapper` handle decimal conversion between the Cosmos SDK's 6-decimal base denom and the EVM's 18-decimal representation.

### 3.2 x/erc20 — Single Token Representation v2

**Module name:** `erc20` | **Store key:** `erc20`

Bridges Cosmos SDK bank tokens and ERC-20 tokens so every token has a single canonical representation accessible from both environments.

**Key responsibilities:**
- Register token pairs mapping Cosmos denoms to ERC-20 precompile addresses
- Convert between bank coins and ERC-20 representations (`ConvertCoin`, `ConvertERC20`)
- Manage ERC-20 allowances for precompile-based tokens
- IBC middleware that automatically converts received IBC tokens to ERC-20

**Msg types:** `MsgConvertERC20`, `MsgConvertCoin`, `MsgUpdateParams`, `MsgRegisterERC20`, `MsgToggleConversion`

**State layout:** Token pairs (by ID, by ERC20 address, by denom), STRv2 address flags, allowances, native and dynamic precompile registrations.

### 3.3 x/feemarket — EIP-1559 Fee Market

**Module name:** `feemarket` | **Store key:** `feemarket`

Implements Ethereum's EIP-1559 dynamic base fee mechanism adapted for Cosmos SDK.

**Key responsibilities:**
- Calculate base fee each block based on parent block gas usage vs target
- Track block gas wanted in transient store
- Enforce minimum gas price and gas multiplier constraints

**Msg types:** `MsgUpdateParams`

**Parameters:**

| Param | Default | Purpose |
|---|---|---|
| `NoBaseFee` | `false` | Disable dynamic fee entirely |
| `BaseFeeChangeDenominator` | 8 | Controls base fee adjustment speed |
| `ElasticityMultiplier` | 2 | Gas target = max gas / elasticity |
| `BaseFee` | 1,000,000,000 | Initial base fee |
| `MinGasPrice` | 0 | Floor for gas price |
| `MinGasMultiplier` | 0.5 | Minimum fraction of base fee for inclusion |

### 3.4 x/precisebank — Fractional Token Precision

**Module name:** `precisebank` | **Store key:** `precisebank`

Enables sub-unit precision for the native token. Cosmos SDK bank module operates in 6-decimal integer units, but the EVM requires 18-decimal precision. This module tracks the fractional remainder.

**Key responsibilities:**
- Store fractional balances per account (the 12 extra decimal places)
- Handle send, mint, and burn operations with full 18-decimal precision
- Maintain a global remainder to ensure the sum of all fractional balances remains consistent

**State layout:** `0x01 + accAddress` -> fractional amount, `0x02` -> global remainder.

### 3.5 x/ibc — IBC Extensions

Two sub-modules extend standard IBC functionality:

**x/ibc/transfer**: Custom transfer keeper and IBC module that integrates with the ERC-20 middleware. When tokens arrive via ICS-20 transfer, the ERC-20 middleware intercepts `OnRecvPacket` and automatically converts them to their ERC-20 representation.

**x/ibc/callbacks**: `ContractKeeper` that implements `callbacktypes.ContractKeeper`. When IBC packets are acknowledged or time out, this keeper calls designated EVM smart contracts, enabling Solidity contracts to react to cross-chain events. Uses isolated addresses (`GenerateIsolatedAddress`) for security.

---

## 4. EVM Precompiles

Precompiled contracts expose Cosmos SDK functionality to Solidity smart contracts. They are callable from EVM bytecode at fixed addresses using standard `CALL`/`STATICCALL` opcodes.

### Static Precompiles

| Address | Name | Key Methods | Type |
|---|---|---|---|
| `0x100` | **P256** | `Run()` — secp256r1 (NIST P-256) signature verification | Stateless |
| `0x400` | **Bech32** | Address conversion: hex to bech32 and back | Stateless, 6000 base gas |
| `0x800` | **Staking** | `Delegate`, `Undelegate`, `Redelegate`, `CreateValidator`, `EditValidator`, `CancelUnbondingDelegation` + query methods | Stateful |
| `0x801` | **Distribution** | `ClaimRewards`, `WithdrawDelegatorReward`, `WithdrawValidatorCommission`, `FundCommunityPool`, `SetWithdrawAddress` + query methods | Stateful |
| `0x802` | **ICS20** | `Transfer` (IBC token transfer from Solidity), `Denom`, `Denoms`, `DenomHash` | Stateful |
| `0x803` | **Vesting** | Address reserved, not yet implemented | -- |
| `0x804` | **Bank** | `Balances`, `TotalSupply`, `SupplyOf` (read-only queries) | Stateful (queries only) |
| `0x805` | **Gov** | `SubmitProposal`, `Vote`, `VoteWeighted`, `Deposit`, `CancelProposal` + query methods | Stateful |
| `0x806` | **Slashing** | `Unjail`, `GetSigningInfo`, `GetSigningInfos`, `GetParams` | Stateful |
| `0x807` | **ICS02** | `UpdateClient`, `VerifyMembership`, `VerifyNonMembership`, `GetClientState` | Stateful |

### Dynamic Precompiles

| Name | Address | Purpose |
|---|---|---|
| **ERC20** | Per-token (registered via x/erc20) | Standard ERC-20 interface: `Transfer`, `TransferFrom`, `Approve`, `BalanceOf`, `Allowance`, `TotalSupply`, `Name`, `Symbol`, `Decimals` |
| **WERC20** | Per-chain native token | Wrapped native token: inherits ERC-20 + `Deposit` (wrap) and `Withdraw` (unwrap) |

### ABI-Only

| Name | Purpose |
|---|---|
| **Callbacks** | ABI definition for IBC callback interface: `onPacketAcknowledgement`, `onPacketTimeout`. Called by `x/ibc/callbacks` keeper, not directly by users. |

### Precompile Dispatch Flow

```
Solidity contract executes CALL to 0x800
  -> geth VM recognizes precompiled contract address
  -> vm.PrecompiledContract.Run() invoked
  -> ABI method selector dispatches to specific handler (e.g., Delegate)
  -> Handler calls Cosmos SDK keeper method directly
  -> State changes written via both StateDB and SDK keeper
  -> Events emitted as both EVM logs and Cosmos events
  -> Result returned to Solidity caller
```

### Common Infrastructure

All precompiles share infrastructure in `precompiles/common/`: base `Precompile` struct with ABI dispatch, balance handling, revert message formatting, error definitions, and type conversions. Static precompiles are registered via a builder pattern in `precompiles/types/static_precompiles.go` using `DefaultStaticPrecompiles()`.

Each stateful precompile has a corresponding Solidity interface file (e.g., `StakingI.sol`, `DistributionI.sol`) that dApps import to call the precompile from Solidity.

---

## 5. Proto Definitions

### Organization

All protobuf definitions live under `proto/cosmos/evm/` organized by module and version:

```
proto/cosmos/evm/
  ante/v1/          dynamic_fee.proto
  crypto/v1/        ethsecp256k1/keys.proto
  eip712/v1/        web3.proto
  erc20/v1/         erc20.proto, events.proto, genesis.proto, query.proto, tx.proto
  feemarket/v1/     feemarket.proto, events.proto, genesis.proto, query.proto, tx.proto
  precisebank/v1/   genesis.proto, query.proto
  server/v1/        indexer.proto
  vm/v1/            evm.proto, events.proto, genesis.proto, query.proto, tx.proto
```

### Code Generation Pipeline

The Makefile provides proto targets using Docker-based tooling:

| Target | Purpose |
|---|---|
| `make proto-gen` | Generate Go implementations via `scripts/generate_protos.sh` and `scripts/generate_protos_pulsar.sh` |
| `make proto-format` | Format `.proto` files with clang-format |
| `make proto-lint` | Lint with `buf lint` and `protolint` |
| `make proto-check-breaking` | Check for breaking changes against upstream `main` branch |
| `make proto-all` | Run format, lint, and generate in sequence |

Generated Go code lands in two locations:
- Standard protobuf Go types: `x/<module>/types/*.pb.go`
- Pulsar-generated API: `/api/cosmos/evm/` directory

### Key Proto Packages

| Package | Go Import | gRPC Base Path |
|---|---|---|
| `cosmos.evm.vm.v1` | `x/vm/types` | `/cosmos/evm/vm/v1/` |
| `cosmos.evm.erc20.v1` | `x/erc20/types` | `/cosmos/evm/erc20/v1/` |
| `cosmos.evm.feemarket.v1` | `x/feemarket/types` | `/cosmos/evm/feemarket/v1/` |
| `cosmos.evm.precisebank.v1` | `x/precisebank/types` | `/cosmos/evm/precisebank/v1/` |

---

## 6. Transaction Flow

### EVM Transaction (Contract Deploy / Call)

```
1. User submits via JSON-RPC (eth_sendTransaction)
   -> rpc/namespaces/ethereum/eth/api.go

2. RPC Backend converts to Cosmos SDK message
   -> rpc/backend/call_tx.go
   -> Creates MsgEthereumTx wrapping ethtypes.Transaction

3. AnteHandler chain validates (see section below)
   -> ante/ante.go routes to EVM-specific decorator chain
   -> Cosmos path: authz check, reject EVM msgs, min gas, EIP-712
   -> EVM path: setup context -> mempool fee -> global fee -> validate
      -> sig verify -> account verify -> can transfer -> gas consume
      -> increment sequence -> emit event

4. Message server processes
   -> x/vm/keeper/msg_server.go EthereumTx()

5. State transition executes
   -> x/vm/keeper/state_transition.go ApplyTransaction()
   -> Creates cache context for atomic commit/revert
   -> Builds geth EVM instance with block context, tx context, chain config
   -> Executes via geth core VM (contract creation or message call)
   -> Precompiles accessible during execution at registered addresses

6. State commits
   -> StateDB changes flush to Cosmos KVStore
   -> Bloom filter computed from logs
   -> Receipt generated with status, gas used, logs, contract address
   -> PostTxProcessing hooks run (e.g., ERC-20 conversion hooks)
   -> Cache context committed (or reverted on failure)

7. Response returned
   -> MsgEthereumTxResponse with gas used, logs, return data, vm error
   -> JSON-RPC formats as standard Ethereum transaction receipt
```

### AnteHandler Routing

The ante handler at `/ante/ante.go` inspects each transaction and routes it:

- **Cosmos transactions**: Standard SDK ante decorators (sig verify, fee deduction, etc.) plus custom checks for authz nesting, EVM message rejection, and min gas price.
- **EVM transactions** (identified by `ExtensionOptionsEthereumTx`): Specialized 9-step decorator chain that handles EVM-specific validation, Ethereum signature verification, account state checks, gas metering, and sequence incrementing.
- A **mono decorator** (`ante/evm/mono_decorator.go`) provides an optimized all-in-one alternative.

---

## 7. Consensus & Validation

### CometBFT Integration

The chain uses CometBFT v0.39.0-beta.2 for Byzantine fault-tolerant consensus. Block production follows the standard Tendermint BFT algorithm:

1. **Propose**: Selected proposer builds a block from the mempool
2. **Prevote**: Validators verify the block and broadcast prevotes
3. **Precommit**: On 2/3+ prevotes, validators precommit
4. **Commit**: On 2/3+ precommits, the block is finalized (single-slot finality)

### ABCI Lifecycle

| Phase | EVM-Specific Behavior |
|---|---|
| `BeginBlock` | `x/vm` sets block proposer for COINBASE opcode; `x/feemarket` calculates new base fee |
| `DeliverTx` | AnteHandler routes to EVM or Cosmos path; `x/vm` executes EVM transactions |
| `EndBlock` | `x/feemarket` updates block gas wanted for next base fee calculation |
| `Commit` | StateDB changes persisted; object store (bloom, gas) reset |

### Validator Mechanics

Validators use `eth_secp256k1` keys for Ethereum address compatibility. The staking module manages validator set changes through standard Cosmos SDK staking. Validators are accessible from Solidity via the Staking precompile at `0x800`, which supports `CreateValidator`, `EditValidator`, `Delegate`, `Undelegate`, and `Redelegate`.

### Custom Mempool

The `/mempool/` directory contains a custom EVM-aware appside mempool that respects EVM transaction ordering semantics (nonce ordering, gas price priority) while integrating with CometBFT's proposal mechanism.

---

## 8. IBC Integration

### Architecture

IBC support is layered through middleware and custom modules:

```
IBC Core (ibc-go v10)
  -> x/ibc/transfer (custom transfer keeper)
    -> ERC-20 IBC Middleware (x/erc20/ibc_middleware.go)
      -> x/ibc/callbacks (ContractKeeper)
```

### ICS-20 Token Transfers

When tokens arrive via ICS-20:

1. Standard IBC transfer module receives the packet
2. ERC-20 middleware intercepts `OnRecvPacket`
3. Tokens are automatically converted to their ERC-20 representation
4. If conversion fails, the user receives the standard bank token as fallback

The ICS20 precompile (`0x802`) allows Solidity contracts to initiate outbound IBC transfers directly, with methods for `Transfer`, `Denom`, `Denoms`, and `DenomHash`.

### IBC Callbacks

The `x/ibc/callbacks` module implements `callbacktypes.ContractKeeper`:

- **IBCSendPacketCallback**: Not supported (returns nil). Contracts implement pre-send logic themselves.
- **IBCReceivePacketCallback**: Unmarshals packet data, extracts callback data, generates an isolated security address, and calls the designated EVM contract.
- **IBCOnAcknowledgementPacketCallback / IBCOnTimeoutPacketCallback**: Calls `onPacketAcknowledgement` or `onPacketTimeout` on the sender contract, enabling Solidity contracts to handle cross-chain completion or failure.

### ICS-02 Light Clients

The ICS02 precompile (`0x807`) exposes IBC light client operations to Solidity: `UpdateClient`, `VerifyMembership`, `VerifyNonMembership`, and `GetClientState`. This enables on-chain verification of cross-chain state proofs from smart contracts.

### EVM Channels

The `x/vm` params include an `EVMChannels` field that whitelists IBC channels authorized for EVM-related operations, providing a security boundary for cross-chain EVM interactions.

---

## 9. Fee Market

### EIP-1559 Implementation

The `x/feemarket` module adapts Ethereum's EIP-1559 to the Cosmos SDK context. The implementation in `x/feemarket/keeper/eip1559.go` calculates the base fee each block:

1. **Activation**: Base fee calculation begins at `EnableHeight`. Before that, the genesis `BaseFee` is used.
2. **Gas target**: `MaxBlockGas / ElasticityMultiplier` (default: max gas / 2).
3. **Adjustment**: If parent block gas > target, base fee increases. If below, it decreases.
4. **Change rate**: Controlled by `BaseFeeChangeDenominator` (default 8, meaning max 12.5% change per block).
5. **Floor**: `MinGasPrice` provides a hard floor; `MinGasMultiplier` ensures inclusion requires at least 50% of base fee.

### Decimal Conversion

A key complexity: the Cosmos SDK bank module uses 6-decimal precision (e.g., `uatom`), while the EVM expects 18-decimal precision (e.g., `wei`). The `x/vm/wrappers/bank.go` `BankWrapper` and `x/vm/wrappers/feemarket.go` `FeeMarketWrapper` handle this conversion. The `x/precisebank` module stores the extra 12 decimal places.

The `EvmCoinInfo` type tracks: base denom (6-decimal), extended denom (18-decimal), display denom, and decimal count. A `ConversionFactor()` bridges between the two.

### Gas Flow

EVM gas metering deliberately ignores the SDK's `GasKVStore` consumption (which charges for state reads/writes). Instead, gas is consumed according to EVM opcode costs. The `ApplyTransaction` function:

1. Saves the starting gas meter
2. Replaces it with an infinite gas meter for the EVM execution context
3. Runs the EVM, which tracks gas internally
4. Adds EVM gas consumed back to the original meter
5. Handles gas refunds per EVM rules

---

## 10. Security

### Audit Status

Two rounds of security audit have been performed on the RPC layer:

| Round | Issues | Critical | High | Medium | Low | Fixed |
|---|---|---|---|---|---|---|
| Round 1 | 16 | 0 | 3 | 9 | 4 | 16 |
| Round 2 | 33 | 5 | 8 | 15 | 5 | 9 |
| **Total** | **49** | **5** | **11** | **24** | **9** | **25** |

Full findings: `docs/audit-comprehensive-findings.md` and `docs/audit-round2-findings.md`.

### Critical Findings (Round 2)

- **C1**: WebSocket subscriptions unlimited — OOM via unlimited subscriptions per connection
- **C2/C3**: `panic()` calls in stream and backend initialization crash the node
- **C4**: EVM Chain ID overflow when `ChainID > MaxInt64`
- **C5**: `effectiveGasPrice` defaults to 0 for legacy transactions instead of `tx.GasPrice()`

### Key Security Patterns

**Integer overflow protection**: `utils/int.go` provides `SafeInt32ToUint()`, `SafeInt64()`, `SafeUint64()`, `SafeHexToInt64()` with bounds checking. Multiple `#nosec G115` annotations have been replaced with safe cast helpers.

**Precompile isolation**: Each precompile validates caller permissions, checks balances before state mutations, and emits events through both EVM logs and Cosmos events for auditability.

**IBC callback isolation**: `GenerateIsolatedAddress(channelID, sender)` creates unique deterministic addresses for IBC callback execution, preventing cross-channel interference.

**State revert on failure**: `ApplyTransaction` uses `ctx.CacheContext()` to create an atomic execution scope. If the transaction or post-processing hooks fail, all state changes revert.

**Access control**: The `AccessControl` parameter in `x/vm` supports three modes for contract creation and calls: `Permissionless` (anyone), `Restricted` (allowlist), and `Permissioned` (governance only). Hooks enforce these policies during EVM opcode execution.

### Address Conversion

The Bech32 precompile (`0x400`) and the `encoding/` package handle bidirectional conversion between Ethereum hex addresses (`0x...`) and Cosmos bech32 addresses (`integra1...`). Both address formats reference the same underlying account. The `eth_secp256k1` key algorithm generates Ethereum-compatible keys that work in both ecosystems.

**Critical gotcha**: The default `secp256k1` key algorithm creates Cosmos-only keys. Validators and users must use `--algo eth_secp256k1` for EVM compatibility.

---

## 11. Build & Test

### Build System

All builds require `CGO_ENABLED=1` (gcc/clang must be installed).

| Target | Description |
|---|---|
| `make build` | Build `evmd` binary to `./build/evmd` |
| `make install` | Install `evmd` to `$GOPATH/bin` |
| `make build-linux` | Cross-compile for Linux AMD64 |
| `make vulncheck` | Run `govulncheck` vulnerability scanner |

**Build flags**: `-tags "netgo"`, ldflags inject version/commit/CometBFT version. Optional DB backends (`cleveldb`, `rocksdb`) via `COSMOS_BUILD_OPTIONS`. Debug builds with `nooptimization` for remote debugging. Static linking with `staticlink`.

**Integra binary**: `cd integra && make install` produces the `intgd` binary.

### Test Organization

| Target | Scope | Framework |
|---|---|---|
| `make test-unit` | Core library unit tests (15m timeout) | Go test + Ginkgo/Gomega |
| `make test-evmd` | evmd-specific tests with race detection | Go test |
| `make test-unit-cover` | Coverage report (merged across root + evmd modules) | Go test |
| `make test-race` | Race condition detection | Go test `-race` |
| `make test-fuzz` | Fuzz testing (precisebank: mint, burn, send, genesis) | Go fuzz |
| `make test-solidity` | Solidity contract tests | Foundry (forge) + Hardhat |
| `make test-scripts` | Script tests | pytest |
| `make benchmark` | Performance benchmarks | Go bench |

### Test Directories

| Location | Contents |
|---|---|
| `evmd/tests/integration/` | Integration tests for all modules: ante handlers, precompiles (bank, bech32, distribution, erc20, gov, ics20, p256, slashing, staking, werc20), EIP-7702, mempool, wallets |
| `evmd/tests/ibc/` | IBC middleware, ICS-02/ICS-20 precompile, recursive precompile calls, v2 protocol tests |
| `evmd/tests/ledger/` | Ledger hardware wallet integration (with mocks) |
| `evmd/tests/network/` | Multi-node test network harness |
| `integra/tests/` | Mirror of evmd tests for Integra-specific chain configuration |
| `tests/integration/` | Shared integration test utilities |
| `tests/jsonrpc/` | JSON-RPC compliance simulator |
| `tests/systemtests/` | End-to-end system tests |
| `tests/solidity/` | Solidity test contracts and Hardhat/Foundry configuration |
| `tests/contracts/` | Solidity test contracts (EIP-7702, account abstraction) |
| `tests/speedtest/` | Performance benchmarks |

### Coverage Filtering

The coverage pipeline (`make test-unit-cover`) merges root and evmd coverage, then filters out generated code, protobuf files, test utilities, mocks, and CLI code to produce a meaningful `coverage.txt`.

### Linting

| Target | Tool |
|---|---|
| `make lint-go` | golangci-lint v2.2.2 |
| `make lint-python` | pylint + flake8 |
| `make lint-contracts` | solhint |
| `make format-go` | gofumpt |

### CI Ports (Default)

| Service | Port |
|---|---|
| CometBFT RPC | 26657 |
| JSON-RPC (HTTP) | 8545 |
| JSON-RPC (WebSocket) | 8546 |
| gRPC | 9090 |
| gRPC-web | 9091 |
| REST API | 1317 |

---

## 12. Key Design Decisions

### Why Cosmos SDK + EVM?

The Cosmos SDK provides a mature application framework with modular governance, staking, IBC cross-chain communication, and single-slot finality via CometBFT. Adding EVM compatibility brings the Ethereum developer ecosystem (Solidity, tooling, DeFi composability) without sacrificing these Cosmos-native capabilities. The alternative -- running a standalone EVM chain -- would lose IBC, governance, and the Cosmos module ecosystem.

### Precompile Design over Bridge Contracts

Rather than deploying bridge contracts that relay messages between EVM and Cosmos, the architecture uses **precompiled contracts** that call Cosmos SDK keeper methods directly during EVM execution. This design:

- Executes atomically within a single transaction (no async relaying)
- Avoids the complexity and security risks of message-passing bridges
- Provides native gas metering for Cosmos operations
- Enables Solidity contracts to compose with staking, governance, and IBC as first-class operations

The tradeoff is implementation complexity: each precompile must carefully manage state across both the EVM StateDB and Cosmos KVStore, handle event emission in both formats, and validate permissions.

### Single Token Representation (STRv2)

The ERC-20 module implements "Single Token Representation" -- every token has exactly one canonical representation. This avoids the confusion of having separate "bank token" and "ERC-20 token" balances for the same asset. The x/erc20 middleware automatically converts tokens on IBC receive, and the dynamic ERC-20 precompile makes all registered tokens accessible from Solidity.

### Module Boundaries

| Decision | Rationale |
|---|---|
| Separate `x/feemarket` from `x/vm` | Fee market logic is independently governable and testable |
| Separate `x/precisebank` from bank | Avoids modifying the upstream Cosmos SDK bank module |
| Separate `x/erc20` from `x/vm` | Token representation is a distinct concern from EVM execution |
| IBC as middleware, not module | Intercepts token transfers without replacing the standard transfer module |

### Geth Fork, Not Standard go-ethereum

The chain uses a Cosmos-specific fork of go-ethereum (v1.16.7) that adds hooks for custom opcodes, precompile dispatch, and access control. Standard geth packages are **not compatible** -- importing them will cause build failures.

### Access Control for Contract Deployment

The `AccessControl` param supports restricting who can deploy contracts (`Permissionless`, `Restricted` with allowlist, `Permissioned` via governance). This is enforced at the opcode level through `CREATE`/`CREATE2` hooks, not just at the transaction level, preventing circumvention through factory contracts.

### EVM Chain ID vs Cosmos Chain ID

These are distinct values. The Cosmos chain ID is a string (`integra-1`), while the EVM chain ID is a numeric value (`26217`) used in EIP-155 transaction signing and MetaMask configuration. The EVM chain ID is set in `app.toml` under `[evm]`, and a common deployment error is leaving it at the default `262144` instead of the chain-specific value.
