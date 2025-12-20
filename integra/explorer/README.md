# Integra Block Explorer (Blockscout)

Open-source EVM block explorer for Integra Chain.

## Quick Start

```bash
# Make sure Integra node is running first
cd /path/to/integra-evm
./bin/intgd start --home ~/.integra

# Start the explorer
cd integra/explorer
docker-compose up -d
```

## Access

- **Frontend**: http://localhost:3000
- **API**: http://localhost:4000/api

## Configuration

Edit `docker-compose.yml` to change:

- `ETHEREUM_JSONRPC_HTTP_URL` - Your node's JSON-RPC endpoint
- `ETHEREUM_JSONRPC_WS_URL` - Your node's WebSocket endpoint
- `CHAIN_ID` - Your EVM chain ID (default: 1343)

## For Production

1. Update `ETHEREUM_JSONRPC_*` URLs to your production node
2. Change `SECRET_KEY_BASE` to a secure random string
3. Consider using nginx/traefik for SSL termination
4. Set `NEXT_PUBLIC_IS_TESTNET: "false"` for mainnet

## Alternative Explorers

### Otterscan (Lightweight)
```bash
docker run -p 5100:80 \
  -e ERIGON_URL=http://your-node:8545 \
  otterscan/otterscan:latest
```

### Expedition (Minimal)
```bash
git clone https://github.com/xops/expedition.git
cd expedition && npm install
REACT_APP_ETH_RPC_URL=http://localhost:8545 npm start
```

