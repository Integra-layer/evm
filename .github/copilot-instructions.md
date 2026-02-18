# Cosmos EVM — Integra Network

Cosmos EVM adds full EVM compatibility to Cosmos SDK chains. This repo contains both the generic `evmd` example and the Integra Network implementation.

## Stack

- Go 1.25 (CGO required)
- Cosmos SDK v0.54.0
- CometBFT v0.39.0
- IBC-Go v10.0.0
- Geth v1.16.7 (Cosmos fork, NOT standard go-ethereum)
- Foundry (Solidity precompile tests)

## Chain Context

- **Token:** IRL (base denom: `airl`, 1 IRL = 10^18 airl)
- **CRITICAL:** Token is IRL/airl, NOT ILR/ailr
- **Mainnet:** `integra-1` (EVM Chain ID: `26217`)
- **Testnet:** `integra-testnet-1` (EVM Chain ID: `26218`)
- **CRITICAL:** Default EVM chain ID after `intgd init` is `262144` (WRONG) — must set to `26217` or `26218`

## Project Structure

```
x/                    # Custom Cosmos SDK modules
  vm/                 # Core EVM execution, state, gas metering
  erc20/              # IBC <-> ERC-20 bridge (Single Token Representation v2)
  feemarket/          # EIP-1559 dynamic base fee
  precisebank/        # Sub-unit fractional tokens
  ibc/                # IBC extensions and callbacks
precompiles/          # 12 stateful precompiles (0x800-0x80B)
integra/              # Integra Network app (app.go, config/)
evmd/                 # Generic example chain
api/                  # Protobuf API definitions
tests/                # Integration tests
```

## Five Custom Modules

1. **x/vm** — Core EVM execution, state management, gas metering, hooks
2. **x/erc20** — IBC-ERC20 bridge, automatic token pair registration
3. **x/feemarket** — EIP-1559 base fee, block gas target, elasticity
4. **x/precisebank** — Sub-unit precision for tokens
5. **x/ibc** — IBC transfer callbacks, ICS-20, cross-chain EVM

## Twelve Precompiles (0x800-0x80B)

Staking, Distribution, ICS20, ICS02, Authz, Bank, Slashing, Gov, p256, bech32, Vesting, ERC20

## Commands

```bash
make build                    # Build intgd binary (CGO_ENABLED=1)
make test                     # Run all Go tests
make test-unit                # Unit tests only
go test ./x/vm/...            # Test specific module
forge test                    # Solidity precompile tests
make proto-gen                # Regenerate protobuf
make lint                     # golangci-lint
```

## Coding Standards

- ALL token amounts MUST use `math/big.Int` or `sdkmath.Int` — NEVER `int64` or `strconv.ParseInt` for amounts
- Follow Cosmos SDK keeper patterns: `Keeper` struct, `msgServer`, `queryServer`
- All keeper methods take `context.Context` as first parameter
- Use `cosmossdk.io/errors` for error wrapping (NOT `fmt.Errorf` for sentinel errors)
- Events must be emitted for all state changes via `ctx.EventManager().EmitEvent()`
- No `panic()` in production code — return errors
- Precompile methods must validate gas costs before execution
- AnteHandler modifications require thorough testing of fee deduction and sig verification
