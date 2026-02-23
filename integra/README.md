# Integralayer Network

This directory contains the Integralayer network implementation using Cosmos EVM
modules. It builds the `intgd` binary for running Integralayer validator nodes.

For validator deployment guides, see: https://github.com/Integra-layer/validator-skill

## Config

| Option              | Value                                           |
|---------------------|------------------------------------------------|
| Binary              | `intgd`                                         |
| Chain ID (Mainnet)  | `integra-1`                                     |
| Chain ID (Testnet)  | `integra-testnet-1`                              |
| EVM Chain ID        | `26217` (mainnet) / `26218` (testnet)            |
| Custom Opcodes      | -                                               |
| Default Token Pairs | 1 for the native token                          |
| Denomination        | `airl` (display: IRL)                           |
| EVM permissioning   | permissionless                                  |
| Enabled Precompiles | all                                             |

> **Warning**: The default EVM chain ID after `intgd init` is `262144` (wrong). You must set it to `26217` (mainnet) or `26218` (testnet) in `app.toml` under `[evm]`.

## Building

```bash
cd integra
make install    # Installs intgd to $GOPATH/bin
intgd version
```

> **Important**: Build from this `integra/` subdirectory, NOT the repository root. Running `make install` at the root builds the generic `evmd` binary.

## Running a Local Dev Node

```bash
./local_node.sh [FLAGS]
```

Available flags:

- `-y`: Overwrite previous database
- `-n`: Do **not** overwrite previous database
- `--no-install`: Skip installation of the binary
- `--remote-debugging`: Build a binary suitable for remote debugging

## Running a Validator (Docker)

For production validator deployment, use the validator-skill repo:

```bash
git clone https://github.com/Integra-layer/validator-skill.git
cd validator-skill
docker compose -f docker-compose.testnet.yml up -d
```

See https://github.com/Integra-layer/validator-skill for full instructions.

## Connect to Wallet (Local Dev)

For local development with MetaMask:

1. Add custom network with RPC URL `http://localhost:8545`
2. EVM Chain ID: `26217` (mainnet) or `26218` (testnet)
3. Token symbol: `IRL`

## Available Cosmos SDK Modules

As mentioned above, this exemplary chain implementation is a reduced version of `simapp`.
Specifically, instead of offering access to all Cosmos SDK modules, it just includes the following:

- `auth`
- `authz`
- `bank`
- `capability`
- `consensus`
- `distribution`
- `evidence`
- `feegrant`
- `genutil`
- `gov`
- `mint`
- `params`
- `slashing`
- `staking`
- `upgrade`
