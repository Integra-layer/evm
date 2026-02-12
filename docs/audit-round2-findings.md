# Integra EVM RPC Audit — Round 2 Findings

## Cross-referenced against 103 Delve research evidence chunks

### CRITICAL (5)

| ID | Issue | File:Line | Description |
|----|-------|-----------|-------------|
| C1 | WS subscriptions unlimited | websockets.go:304 | No per-connection limit. OOM via unlimited subscriptions |
| C2 | Stream init panics | stream/rpc.go:91,99 | panic(err) on subscription failure crashes node |
| C3 | Backend init panics | backend/backend.go:199,204 | panic(err) on config/client assertion crashes startup |
| C4 | EVMChainID overflow | backend/backend.go:212 | big.NewInt(int64(uint64)) overflows if ChainID > MaxInt64 |
| C5 | effectiveGasPrice wrong for legacy txs | comet_to_eth.go:298 | Defaults to 0, should be tx.GasPrice() per EIP-1559 |

### HIGH (8)

| ID | Issue | File:Line | Description |
|----|-------|-----------|-------------|
| H1 | WS newHeads missing GasLimit/GasUsed | types/utils.go:84-85 | EthHeaderFromComet sets both to 0 |
| H2 | Log transactionIndex mismatch | comet_to_eth.go:314-346 | Logs TxIndex not synced with resolved EthTxIndex |
| H3 | Queue operations panic | stream/queue.go:96,131,141 | Peek/Get/Remove on empty queue panic |
| H4 | int64 multiplication overflow in gas tip | chain_info.go:372 | baseFee * multiplier can overflow |
| H5 | ParseUint->int32 bounds gap | types/events.go:242-246 | ParseUint(31bit) then int32 cast edge case |
| H6 | Unvalidated #nosec casts | comet_to_eth.go:317,346 | uint64(Height)/uint(EthTxIndex) no runtime check |
| H7 | eth_getLogs OOM | filters/filters.go:200 | Limit check after append, not before |
| H8 | Nil baseFee in EffectiveGasTip | backend/utils.go:265 | nil baseFee passed to EffectiveGasTip |

### MEDIUM (15)

| ID | Issue | File:Line | Description |
|----|-------|-----------|-------------|
| M1 | WS newHeads missing block hash | websockets.go:465 | Direct header, no hash field |
| M2 | WS missing bloom/receiptsRoot | types/utils.go:81,87 | Empty defaults for WS headers |
| M3 | Filter not-found wrong error code | filters/api.go:289,334 | Returns -32600, should be -32001 |
| M4 | NewFilter no block range validation | filters/api.go:205 | Invalid fromBlock>toBlock accepted |
| M5 | eth_subscribe ignores fromBlock/toBlock | websockets.go:503 | Block range params silently ignored |
| M6 | Filter timeout race condition | filters/api.go:337 | deadline.Stop/C race |
| M7 | blockHash no filters returns empty | filters/filters.go:209 | Should return all logs in block |
| M8 | (nil,nil) silent failures | backend/headers.go | Errors return nil,nil |
| M9 | Revert reason format | backend/call_tx.go:503-513 | gRPC codes.Internal not JSON-RPC -32003 |
| M10 | Missing args validation | eth/api.go:268-274 | No validation before backend call |
| M11 | Negative oldestBlock | chain_info.go:224-229 | Can go negative for large requests |
| M12 | FeeHistory block overflow | chain_info.go:200-201 | Uint64->int64 without range check |
| M13 | Timestamp uint64 conversion | types/utils.go:73,145 | Unix()→uint64 no negative check |
| M14 | Gas limit int64->uint64 | types/utils.go:143 | No bounds check |
| M15 | Block query race with pruning | backend/blocks.go | Separate fetches can race |

### LOW (5)

| ID | Issue | File:Line | Description |
|----|-------|-----------|-------------|
| L1 | SuggestGasTipCap worst-case | chain_info.go:372-377 | Returns max delta not median |
| L2 | Empty string on filter limit | filters/api.go:154,177 | Empty ID not error |
| L3 | v.Sign()->uint64 edge case | types/utils.go:223+ | -1 wraps to max uint64 |
| L4 | Net/Personal init panics | net/api.go:29 | Namespace setup panics |
| L5 | Bloom length unvalidated | comet_to_eth.go:367 | BytesToBloom no size check |
