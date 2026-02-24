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

## Version Pinning for Validators

**Always build from a specific commit hash** — never from an unverified `main` HEAD for production validators. Using `main` risks pulling untested changes that cause AppHash mismatches and halt the chain.

```bash
# Check which commit your current binary was built from
intgd version --long | grep commit

# Build from a specific tested commit
git fetch --all
git checkout <commit-hash>
cd integra && make install

# Verify the commit matches
intgd version --long
```

> **No release tags exist yet.** Until tagged releases are established, validators should coordinate on specific commit hashes via community channels. The commit hash is embedded in the binary at build time.

## CLI Command Changes (tendermint → comet)

CometBFT replaced Tendermint. Some CLI commands have moved:

| Old (deprecated) | New |
|---|---|
| `intgd tendermint show-validator` | `intgd comet show-validator` |
| `intgd tendermint show-node-id` | `intgd comet show-node-id` |
| `intgd tendermint unsafe-reset-all` | `intgd comet unsafe-reset-all` |
| `intgd tendermint version` | `intgd comet version` |

Both subcommands may work depending on your binary version, but always prefer `comet`.

## Validator Key Safety

The `priv_validator_key.json` file is the identity of your validator. If lost, the validator cannot sign blocks — and if it held significant voting power, the chain will halt.

```bash
# Back up immediately after creating your validator
mkdir -p ~/.integra-backups
cp ~/.intgd/config/priv_validator_key.json ~/.integra-backups/
cp ~/.intgd/config/node_key.json ~/.integra-backups/
```

> **NEVER** run two nodes with the same `priv_validator_key.json` simultaneously.
> This causes double-signing → permanent slashing (tombstoning).

> **NEVER** use `FORCE_INIT=true` on a validator node. It wipes signing keys on restart.

## Upgrade Procedure

```bash
# 1. Stop the node
sudo systemctl stop intgd

# 2. Build the new binary from the agreed-upon commit
cd ~/evm && git fetch --all
git checkout <new-commit>
cd integra && make install

# 3. Verify the new version
intgd version --long

# 4. Restart
sudo systemctl start intgd

# 5. Monitor for AppHash mismatches
journalctl -u intgd -f | grep -i "apphash\|error\|panic"
```

If you see `wrong Block.Header.AppHash`, you are running the wrong binary. Stop, rebuild from the correct commit, and restart.

## Endpoints

**Mainnet:**

| Service | URL |
|---|---|
| Cosmos RPC | `https://rpc.integralayer.com` |
| REST API | `https://api.integralayer.com` |
| EVM JSON-RPC | `https://evm.integralayer.com` |
| Explorer | `https://scan.integralayer.com` |
| Blockscout | `https://blockscout.integralayer.com` |

**Testnet:**

| Service | URL |
|---|---|
| Cosmos RPC | `https://ormos.integralayer.com/cometbft` |
| REST API | `https://ormos.integralayer.com/rest` |
| EVM JSON-RPC | `https://ormos.integralayer.com/rpc` |
| Blockscout | `https://testnet.blockscout.integralayer.com` |

## Available Cosmos SDK Modules

This chain implementation includes the following Cosmos SDK modules:

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

## Resources

- **Docs**: [docs.integralayer.com](https://docs.integralayer.com)
- **Validator Guide**: [docs.integralayer.com/validator](https://docs.integralayer.com/validator)
- **Validator Skill**: [github.com/Integra-layer/validator-skill](https://github.com/Integra-layer/validator-skill)
- **Hub Dashboard**: [integra-connect.vercel.app](https://integra-connect.vercel.app)
- **Upstream Cosmos EVM**: [evm.cosmos.network](https://evm.cosmos.network)
