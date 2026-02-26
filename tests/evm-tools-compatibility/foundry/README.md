# Foundry Compatibility Test

This project showcases how Foundry works seamlessly with a Cosmos-SDK app chain that integrates Cosmos-EVM.
It uses a simple ERC-20 token to validate deployment, minting, and transfer operations.
You can run these tests with both `forge` and `cast` and compare the results side by side.

## Prerequisites

- **Foundry**: Ensure Foundry (`forge` and `cast`) is installed:

  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

- **Local node**: A running Cosmos-SDK / CometBFT chain exposing an Ethereum-compatible RPC endpoint at `$CUSTOM_RPC`.
- **GNU Make** (optional) for convenience.

## Network Configuration

| Network | Chain ID | EVM RPC |
|---------|----------|---------|
| Local | `262144` | `http://127.0.0.1:8545` |
| Testnet | `26218` | `https://testnet.integralayer.com/evm` |
| Mainnet | `26217` | `https://mainnet.integralayer.com/evm` |

Update the `.env` file to match your target network:

```bash
# For testnet:
CHAIN_ID=26218
CUSTOM_RPC=https://testnet.integralayer.com/evm

# For mainnet:
CHAIN_ID=26217
CUSTOM_RPC=https://mainnet.integralayer.com/evm
```

## Initial Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/Integra-layer/evm.git
   cd evm/tests/evm-tools-compatibility/foundry
   ```

2. **Install dependencies**

   ```bash
   forge install
   forge install OpenZeppelin/openzeppelin-contracts@5.3.0
   ```

3. **Create environment file**
   Create a `.env` file in this directory with:

   ```bash
   cp .env.example .env
   # modify .env
   ```

   > **Note:** Do not commit `.env` to version control.

## Usage

### Compile

```bash
forge build
```

### Test ERC20 contract in virtual environment

```bash
source .env
forge test \
  --fork-url $CUSTOM_RPC \
  --chain-id $CHAIN_ID \
  --gas-report
```

### Query Network Info

`cast call`

```bash
./shellscripts/get-network-info.sh
```

`forge script`

```bash
source .env
forge script script/NetworkInfo.s.sol \
  --rpc-url $CUSTOM_RPC \
  --chain-id $CHAIN_ID \
  --broadcast \
  --legacy
```

### Deploy Contract

`forge script`

```bash
source .env
forge script script/DeployERC20.s.sol \
  --rpc-url $CUSTOM_RPC \
  --broadcast \
  --chain-id $CHAIN_ID \
  --legacy
```

### Read State

`cast call`

```bash
./shellscripts/read_state.sh $CONTRACT
```

`forge script`

```bash
source .env
forge script script/ReadState.s.sol:ReadState \
  --rpc-url $CUSTOM_RPC \
  --chain-id $CHAIN_ID \
  --broadcast \
  --legacy
```

### ERC20 Transfer

`cast send`

```bash
./shellscripts/transfer.sh $CONTRACT $ACCOUNT_2 1000000000000000000
```

`forge script`

```bash
source .env
forge script script/Transfer.s.sol:Transfer \
  --rpc-url $CUSTOM_RPC \
  --chain-id $CHAIN_ID \
  --broadcast \
  --legacy
```

### ERC20 Transfer Revert

`cast send`

```bash
source .env
shellscripts/transfer_error.sh
```

`forge script`

```bash
source .env
forge script script/TransferError.s.sol:TransferError \
  --rpc-url $CUSTOM_RPC \
  --chain-id $CHAIN_ID \
  --broadcast \
  --legacy
```

## Common Issues & Notes

- **EIP-1559 not fully supported**: Cosmos-EVM chains require the `--legacy` flag on all `forge script` and `cast send` commands. Without it, transactions will fail with gas estimation errors.

- **Import errors for forge-std or ds-test**:
  Ensure `remappings.txt` exists and contains at least:

  ```text
  forge-std/=lib/forge-std/
  ds-test/=lib/ds-test/src/
  @openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
  ```

  Then restart your editor's language server.

- **Default chain ID is wrong**: `intgd init` sets the EVM chain ID to `262144`. Override it in `.env` — testnet is `26218`, mainnet is `26217`.
