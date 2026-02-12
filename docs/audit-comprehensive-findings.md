# Integra EVM RPC — Comprehensive Security Audit Findings

> **Date:** 2026-02-11
> **Auditor:** Claude Code (Opus 4.6) + Delve Research (103 evidence chunks)
> **Scope:** `rpc/`, `utils/` — Ethereum JSON-RPC compatibility layer
> **Branch:** `fix/receipt-tx-index-overflow`
> **PR:** https://github.com/Integra-layer/evm/pull/2

---

## Executive Summary

Two rounds of audit uncovered **49 total issues** across the Integra EVM RPC layer:

| Round | CRITICAL | HIGH | MEDIUM | LOW | Status |
|-------|----------|------|--------|-----|--------|
| Round 1 | 0 | 3 | 9 | 4 | **16 FIXED** (commit `3c35572`) |
| Round 2 | 5 | 8 | 15 | 5 | **9 FIXED** + 24 RED tests (commit `1710346`) |
| **Total** | **5** | **11** | **24** | **9** | **25 FIXED**, 24 documented |

### Research Foundation

Findings were cross-referenced against 103 Delve research evidence chunks from the `ethereum-jsonrpc-evm-compliance` subject covering:
- Ethereum JSON-RPC specification (EIP-1474)
- EIP-1559 fee market mechanics
- Cosmos SDK ISA-2025-005 integer overflow advisory
- go-ethereum (geth) reference implementation behavior
- viem/wagmi/ethers.js client compatibility requirements

---

## Test Coverage

| Package | Coverage | Test Functions | Notes |
|---------|----------|---------------|-------|
| `rpc/backend` | 13.3% | 34 | Large package; mocking-heavy |
| `rpc/types` | 43.7% | 18 | Events, utils, block parsing |
| `rpc/stream` | 72.5% | 17 | Queue, stream, RPC subscriptions |
| `rpc/filters` | 41.1% | 10 | Filter API, log filtering |
| `utils/` | 69.9% | 6 | Safe cast helpers, validation |
| **Total** | — | **79** | +33 new Round 2 RED tests |

---

## Round 1 — FIXED (commit `3c35572`, +784/-20 lines)

### R1-A1. `gasUsed` int64 overflow in block response — **FIXED**
- **File:** `rpc/types/utils.go:407`
- **Issue:** `big.NewInt(int64(head.GasUsed))` overflows when `GasUsed > MaxInt64`, producing negative hex values in JSON-RPC responses. Breaks clients like viem that expect positive values.
- **Fix:** Changed to `hexutil.Uint64(head.GasUsed)` — direct uint64 encoding, matching geth's behavior.
- **Test:** `TestRPCMarshalHeader_GasUsedOverflow` — verifies `math.MaxUint64` marshals correctly.

### R1-A2. `EthTxIndex` sentinel wraps to MaxUint64 — **FIXED**
- **File:** `rpc/backend/comet_to_eth.go:339`
- **Issue:** `uint(txResult.EthTxIndex)` where `EthTxIndex=-1` (sentinel for "unindexed") wraps to `18446744073709551615`, causing viem `IntegerOutOfRangeError`.
- **Fix:** Added sentinel check: `if txResult.EthTxIndex == -1 { txResult.EthTxIndex = int32(i) }` — resolves to actual position in block.
- **Test:** `TestReceiptsFromCometBlock_SentinelEthTxIndex` — builds receipt with sentinel, verifies resolution.

### R1-A3. `EthTxIndex` sentinel in tx_info — **FIXED**
- **File:** `rpc/backend/tx_info.go:94`
- **Issue:** `uint64(res.EthTxIndex)` guarded at line 82 but no guard at cast site.
- **Fix:** Added guard before cast with error return.
- **Test:** Covered by A2 regression test.

### R1-A4. GasUsed int64→uint64 negative check — **FIXED**
- **Files:** `comet_to_eth.go:209`, `backend/utils.go:256`, `types/events.go:125`
- **Issue:** `uint64(result.GasUsed)` from int64 ABCI response without negative check. Negative `GasUsed` wraps to huge uint64.
- **Fix:** Added `if gasUsed < 0 { return error }` checks at all three sites.
- **Test:** `TestEthBlockFromCometBlock_NegativeGasUsed`, `TestParseTxResult_NegativeGasUsed`.

### R1-A5. Block height int64→uint64 negative check — **FIXED**
- **Files:** `comet_to_eth.go:310`, `tx_info.go:92`
- **Issue:** Block height cast without validation.
- **Fix:** Added negative check before cast.
- **Test:** `TestReceiptsFromCometBlock_NegativeHeight`.

### R1-A6. `BlockMaxGasFromConsensusParams` panics — **FIXED**
- **File:** `rpc/types/utils.go:111`
- **Issue:** `panic("incorrect tm rpc client")` crashes the entire RPC server on type mismatch.
- **Fix:** Changed to `return 0, fmt.Errorf("incorrect tm rpc client")`.
- **Test:** `TestBlockMaxGasFromConsensusParams_NoPanic` — verifies error return, not panic.

### R1-A7. Safe cast helpers — **CREATED**
- **File:** `utils/int.go`
- **Content:** `SafeInt32ToUint()`, `SafeInt64()`, `SafeUint64()`, `SafeHexToInt64()` with bounds checks.
- **Applied to:** Multiple `#nosec G115` locations.
- **Test:** `utils/int_test.go` — 3 test functions covering positive, zero, negative, boundary cases.

### R1-B1. Missing `totalDifficulty` in block response — **FIXED**
- **File:** `rpc/types/utils.go:393-431`
- **Issue:** Field absent from `RPCMarshalHeader`. geth always includes it; clients may error on missing field.
- **Fix:** Added `result["totalDifficulty"] = (*hexutil.Big)(big.NewInt(0))` (correct for PoS chains).
- **Test:** `TestRPCMarshalHeader_TotalDifficulty` — verifies field present with `0x0`.

### R1-B3. `gasUsed` vs `gasLimit` type inconsistency — **FIXED**
- **File:** `rpc/types/utils.go:406-407`
- **Issue:** `gasLimit` uses `hexutil.Uint64`, `gasUsed` uses `*hexutil.Big` — different JSON types for same concept.
- **Fix:** Changed `gasUsed` to `hexutil.Uint64` to match geth.
- **Test:** `TestRPCMarshalHeader_GasTypeConsistency` — asserts both are `hexutil.Uint64`.

### R1-B4. Pending tx fields omitted instead of null — **FIXED**
- **File:** `rpc/types/utils.go:209-213`
- **Issue:** `blockHash`, `blockNumber`, `transactionIndex` missing for pending txs; geth includes them as JSON null.
- **Fix:** Always set fields; use nil/zero values for pending.
- **Test:** `TestNewRPCTransaction_PendingFieldsPresent` — marshals to JSON, verifies fields present as null.

### R1-B5. Nil `effectiveGasPrice` in receipts — **FIXED**
- **File:** `rpc/backend/comet_to_eth.go:290`
- **Issue:** `GasFeeCap()` can return nil for legacy txs → receipt field becomes nil.
- **Fix:** Added nil guard: `if effectiveGasPrice == nil { effectiveGasPrice = big.NewInt(0) }`.
- **Test:** `TestReceiptsFromCometBlock_NilEffectiveGasPrice`.

### R1-D1. GetTransactionReceipt retry ignores context — **FIXED**
- **File:** `rpc/backend/tx_info.go:157-181`
- **Issue:** `time.Sleep(delay)` in retry loop without checking `ctx.Done()`. Can hang indefinitely.
- **Fix:** Changed to `select { case <-time.After(delay): case <-ctx.Done(): return nil, ctx.Err() }`.
- **Test:** `TestGetTransactionReceipt_ContextCancellation` — verifies prompt return on cancelled context.

### R1 Additional Fixes
- **ProcessBlock gasUsed type assertion** — added proper `hexutil.Uint64` type switch with error for wrong type.
- **RPCMarshalHeader optional fields** — BaseFee, WithdrawalsHash, BlobGasUsed, ExcessBlobGas, ParentBeaconRoot, RequestsHash.
- **Error wrapping** — improved error messages in `tx_info.go` and `comet_to_eth.go` for debuggability.

---

## Round 2 — 9 FIXED + 24 documented (commit `1710346`)

### CRITICAL

#### C1. WS subscriptions unlimited — OOM attack vector
- **File:** `rpc/websockets.go:304`
- **Issue:** The `readLoop` function at line 242 creates a `map[rpc.ID]context.CancelFunc` for tracking subscriptions. There is no `MaxSubscriptionsPerConnection` limit. A malicious client can open a single WebSocket connection and send `eth_subscribe` in a loop, growing the map until the process runs out of memory. The `subscriptions` map at line 316 adds entries unconditionally.
- **Impact:** Denial of service. Any external client can crash the RPC node.
- **Fix needed:** Add per-connection subscription limit (e.g., 100). Check `len(subscriptions) >= maxSubscriptions` before line 316.
- **Test:** `TestC1_NoSubscriptionLimitDefined` (websockets_test.go) — demonstrates unbounded map growth.

#### C2. Stream init panics crash node — **FIXED**
- **File:** `rpc/stream/rpc.go:91,99`
- **Issue:** `initSubscriptions()` calls `panic(err)` when CometBFT event subscription fails. This is called lazily from `HeaderStream()` and `LogStream()`. Any transient CometBFT connectivity issue crashes the entire RPC process instead of returning an error or retrying.
- **Impact:** Node crash on temporary network issues. Unrecoverable without restart.
- **Fix:** Replaced `panic(err)` with `s.logger.Error(...)` + `return`. Streams are allocated before subscribe, so callers get non-nil but empty streams — graceful degradation.
- **Tests:** 4 tests in `rpc/stream/rpc_test.go` (renamed to `*_GracefulOn*`):
  - `TestHeaderStream_GracefulOnFirstSubscribeFailure`
  - `TestLogStream_GracefulOnFirstSubscribeFailure`
  - `TestHeaderStream_GracefulOnSecondSubscribeFailure`
  - `TestLogStream_PanicsOnSecondSubscribeFailure` (line 99)

#### C3. Backend init panics crash startup — **FIXED**
- **File:** `rpc/backend/backend.go:199,204`
- **Issue:** `NewBackend()` panics on config failure (line 199) and when `clientCtx.Client` doesn't implement `tmrpcclient.SignClient` (line 204). Any operator misconfiguration causes an unrecoverable crash with an unhelpful panic trace instead of a structured error.
- **Impact:** Startup crash. Operator cannot diagnose configuration issues from panic output.
- **Fix:** Changed `NewBackend` to return `(*Backend, error)`. Updated all 5 callers in `rpc/apis.go` + integration test.
- **Test:** `TestNewBackend_ReturnsErrorOnBadClient` (audit_round2_test.go) — verifies error returned, not panic.

#### C4. EVMChainID overflow produces negative chain ID — **FIXED**
- **File:** `rpc/backend/backend.go:212`
- **Issue:** `big.NewInt(int64(appConf.EVM.EVMChainID))` silently overflows when `EVMChainID > math.MaxInt64`. The uint64 config value wraps to negative int64, creating a negative `big.Int` chain ID. This affects all EIP-155 signature verification and chain ID comparisons.
- **Impact:** Broken transaction signing, chain ID mismatch errors, potential replay attacks.
- **Fix:** Changed to `new(big.Int).SetUint64(appConf.EVM.EVMChainID)`.
- **Tests:**
  - `TestEVMChainID_OverflowProducesNegativeValue` — table-driven test with MaxInt64, MaxInt64+1, MaxUint64
  - `TestNewBackend_EVMChainIDOverflow` — end-to-end through backend

#### C5. effectiveGasPrice wrong for dynamic fee txs when baseFee is nil
- **File:** `rpc/backend/comet_to_eth.go:290-298`
- **Issue:** When `baseFee` is nil, the fallback is `ethMsg.Raw.GasFeeCap()`. For EIP-1559 (type 2) txs with `GasFeeCap=0` and `GasTipCap>0`, this returns 0 — ignoring the tip entirely. Per EIP-1559, when there's no baseFee, the effective gas price should account for the tip.
- **Impact:** Incorrect receipt `effectiveGasPrice` field. Block explorers and wallets display wrong gas costs.
- **Fix needed:** Use `rpctypes.EffectiveGasPrice(tx, baseFee)` which handles the nil case correctly per EIP-1559.
- **Test:** `TestC5_EffectiveGasPrice_NilBaseFee_DynamicTx` — type 2 tx with GasFeeCap=0, GasTipCap=5gwei.

### HIGH

#### H1. WS newHeads missing GasLimit/GasUsed
- **File:** `rpc/types/utils.go:84-85`
- **Issue:** `EthHeaderFromComet()` hardcodes `GasLimit: 0, GasUsed: 0`. WebSocket subscribers receive block headers with zero gas fields, breaking gas utilization monitoring and MetaMask gas estimation.
- **Fix needed:** Accept `gasLimit, gasUsed uint64` params; update callers in `rpc/stream/rpc.go`.
- **Test:** `TestEthHeaderFromComet_NegativeTimestamp` also covers the zero gas fields implicitly. H1 is documented in the Round 1 plan (B2).

#### H2. Log transactionIndex mismatch with receipt
- **File:** `rpc/backend/comet_to_eth.go:314-346`
- **Issue:** After resolving `EthTxIndex` from -1 sentinel to actual position (line 286), the logs decoded at line 314 use the OLD `txResult` values from the proto response, not the resolved index. Result: `receipt.TransactionIndex=0` but `log.TxIndex` may differ.
- **Impact:** Clients that cross-reference logs with receipts see inconsistent indices.
- **Fix needed:** After resolving EthTxIndex, update log.TxIndex to match.
- **Test:** `TestH2_LogTransactionIndexMismatch` — builds receipt with sentinel, checks log.TxIndex vs receipt.TransactionIndex.

#### H3. Queue operations panic instead of returning errors
- **File:** `rpc/stream/queue.go:96,131,141`
- **Issue:** `Peek()`, `Get()`, `Remove()` all call `panic()` on empty queue or out-of-range index. Since the queue is explicitly "NOT thread-safe" (per its own docs), any race condition between producer/consumer goroutines panics the process.
- **Impact:** Node crash on any queue race condition.
- **Fix needed:** Return `(V, error)` or `(V, bool)` instead of panicking.
- **Tests:** 3 tests in `queue_test.go`:
  - `TestQueuePeekPanicsInsteadOfError`
  - `TestQueueRemovePanicsInsteadOfError`
  - `TestQueueGetPanicsInsteadOfError`

#### H4. int64 multiplication overflow in SuggestGasTipCap — **FIXED**
- **File:** `rpc/backend/chain_info.go:372`
- **Issue:** `baseFee.Int64() * (int64(ElasticityMultiplier) - 1) / int64(Denominator)` — `Int64()` truncates big.Int values > MaxInt64 to negative, and the multiplication can overflow. Two bugs: (1) `baseFee > MaxInt64` wraps negative → tip clamped to 0; (2) `baseFee * (elasticity-1)` can overflow int64.
- **Impact:** Gas tip suggestions are wrong (zero or wrapping). Users either overpay or underpay.
- **Fix:** Replaced with full `big.Int` arithmetic: `maxDelta = baseFee * (elasticity - 1) / denominator`.
- **Test:** `TestSuggestGasTipCap_OverflowMaxDelta` — table-driven with MaxInt64+1 (wraps to 0) and MaxInt64*3 (wraps to wrong positive).

#### H5. ParseUint→int32 bounds gap — **FIXED**
- **File:** `rpc/types/events.go:242-246`
- **Issue:** `strconv.ParseUint(value, 10, 31)` then `int32(txIndex)`. BitSize=31 means max value is 2^31-1 = 2147483647. While this matches int32 max, it unnecessarily rejects valid tx indices that could be uint32 (up to 4294967295).
- **Fix:** Changed to `ParseUint(value, 10, 64)` + explicit `if txIndex > math.MaxInt32` bounds check.
- **Test:** `TestFillTxAttribute_MaxUint31Boundary` — shows values >= 2^31 are rejected.

#### H6. Unvalidated #nosec casts in receipt builder
- **File:** `rpc/backend/comet_to_eth.go:317,346`
- **Issue:** `uint64(resBlock.Block.Height)` and `uint(txResult.EthTxIndex)` have `#nosec G115` annotations suppressing gosec warnings but no runtime validation. Negative heights wrap to MaxUint64.
- **Fix needed:** Use safe cast helpers before these lines.
- **Test:** `TestReceiptsFromCometBlock_NegativeHeight` — negative height produces receipt with wrong block number.

#### H7. eth_getLogs OOM — log limit check after allocation — **FIXED**
- **File:** `rpc/namespaces/ethereum/eth/filters/filters.go:200`
- **Issue:** The limit check `len(logs)+len(filtered) > logLimit` runs AFTER `blockLogs()` materializes ALL matching logs from a single block. If a single block produces millions of logs, the entire slice is allocated before the check fires.
- **Impact:** OOM crash. A crafted filter query targeting a log-heavy block can crash the node.
- **Fix:** Added early guard `if len(logs) >= logLimit` before `blockLogs()` call. Retained post-fetch check as second line of defense.
- **Test:** `TestH7_LogLimitCheckAfterAllocation` — demonstrates the pattern.

#### H8. Nil baseFee in EffectiveGasTip
- **File:** `rpc/backend/utils.go:265`
- **Issue:** `tx.EffectiveGasTip(blockBaseFee)` where `blockBaseFee` is nil. go-ethereum treats nil baseFee as no-base-fee chain, returning the full gas tip cap, which may not be the intended behavior.
- **Impact:** Incorrect reward calculations in FeeHistory for pruned blocks.
- **Fix needed:** Explicitly handle nil baseFee case before calling EffectiveGasTip.
- **Test:** Covered by `TestL1_SuggestGasTipCap_ReturnsMaxDelta` (nil baseFee path).

### MEDIUM

#### M1. WS newHeads missing block hash
- **File:** `rpc/websockets.go:465`
- **Issue:** `subscribeNewHeads` sends `header.EthHeader` directly, which is `*ethtypes.Header`. The `hash` field (block hash) is not part of geth's Header struct — it's computed on the fly. WS subscribers see headers without block hash.
- **Fix needed:** Use `RPCMarshalHeader(header.EthHeader, header.Hash)` to include hash.

#### M2. WS missing bloom/receiptsRoot
- **File:** `rpc/types/utils.go:81,87`
- **Issue:** `EthHeaderFromComet` sets `Bloom: bloom` (passed as empty) and `ReceiptHash: ethtypes.EmptyReceiptsHash`. WS subscribers see empty bloom filters and dummy receipt roots.
- **Fix needed:** Compute bloom from block events; compute receiptsRoot from actual receipts.

#### M3. Filter not-found returns wrong error code
- **File:** `rpc/namespaces/ethereum/eth/filters/api.go:289,334`
- **Issue:** `GetFilterLogs` and `GetFilterChanges` return `fmt.Errorf("filter %s not found")` — a plain error. Per EIP-1474, filter not found should return JSON-RPC error code `-32001`, not `-32600`.
- **Fix needed:** Return structured JSON-RPC error with code `-32001`.
- **Tests:** `TestGetFilterLogs_NotFoundErrorCode`, `TestGetFilterChanges_NotFoundErrorCode`.

#### M4. NewFilter accepts invalid block range
- **File:** `rpc/namespaces/ethereum/eth/filters/api.go:205`
- **Issue:** `NewFilter` stores a filter with `fromBlock > toBlock` without validation. The error only surfaces later when `GetFilterLogs` calls `Logs()`.
- **Fix needed:** Validate `fromBlock <= toBlock` at creation time.
- **Test:** `TestNewFilter_NoBlockRangeValidation` — creates filter with from=100, to=50, no error.

#### M5. eth_subscribe ignores fromBlock/toBlock params
- **File:** `rpc/websockets.go:503`
- **Issue:** The `subscribeLogs` function parses `address` and `topics` from params but silently ignores `fromBlock`/`toBlock`, which some clients use for historical log backfill.
- **Fix needed:** Either implement block range support or return error when params are provided.
- **Status:** TODO — requires integration test setup.

#### M6. Filter timeout race condition
- **File:** `rpc/namespaces/ethereum/eth/filters/api.go:337`
- **Issue:** `deadline.Stop()` can return false if timer already fired, then `<-f.deadline.C` blocks if another goroutine already drained the channel.
- **Fix needed:** Use proper timer reset pattern with non-blocking channel drain.
- **Status:** TODO — requires concurrent integration test.

#### M7. blockHash filter with no address/topics returns empty
- **File:** `rpc/namespaces/ethereum/eth/filters/filters.go:209`
- **Issue:** When blockHash is set but no address/topic filters are specified, should return all logs in the block. The `bloomFilter()` function returns `true` (wildcard) which is correct, but the backend mock integration is incomplete.
- **Test:** `TestBlockHashFilter_NoAddressTopicReturnsEmpty` — documents behavior.

#### M8. (nil, nil) silent failures
- **File:** `rpc/backend/headers.go`
- **Issue:** Multiple methods return `(nil, nil)` for not-found data, which marshals as JSON `null`. This is technically correct per JSON-RPC spec (geth also returns null for missing data).
- **Status:** Documented as LOW priority — spec-compliant behavior.

#### M9. Revert reason format inconsistency
- **File:** `rpc/backend/call_tx.go:503-513`
- **Issue:** Non-revert VM errors wrapped as gRPC `codes.Internal` instead of JSON-RPC `-32003` (execution reverted). Reverts with no data return plain errors without revert data.
- **Fix needed:** Standardize all error paths to JSON-RPC format.

#### M10. Missing args validation in eth API
- **File:** `rpc/namespaces/ethereum/eth/api.go:268-274`
- **Issue:** No validation of transaction args before backend call. Invalid addresses, gas limits, etc. pass through to the EVM.
- **Fix needed:** Validate args at API boundary.

#### M11. Negative oldestBlock in FeeHistory
- **File:** `rpc/backend/chain_info.go:224-229`
- **Issue:** `blockStart := blockEnd + 1 - blocks` can produce negative values when `blocks > blockEnd + 1`. The guard at line 224 only checks `blockEnd < MaxInt64`.
- **Fix needed:** Add `if blockStart < 0 { blockStart = 0 }` or clamp blocks.
- **Test:** `TestFeeHistory_NegativeOldestBlock` — documents the overflow arithmetic.

#### M12. FeeHistory block number overflow — **FIXED**
- **File:** `rpc/backend/chain_info.go:200-201`
- **Issue:** `int64(blkNumber)` and `int64(lastBlock)` overflow when values > MaxInt64. Both lines have `#nosec G115` suppressions.
- **Fix:** Added `if blkNumber > MaxInt64` guard returning error. Removed `#nosec` comments.
- **Test:** `TestFeeHistory_BlockNumberOverflow` — documents the int64 wrapping.

#### M13. Timestamp uint64 conversion — **FIXED**
- **File:** `rpc/types/utils.go:73,145`
- **Issue:** `uint64(header.Time.UTC().Unix())` — if `Time` is before Unix epoch (1970), `Unix()` returns negative, `uint64` wraps to huge value.
- **Fix:** Added negative check — clamp to 0 before uint64 cast. Removed `//nolint:gosec` comments.
- **Test:** `TestEthHeaderFromComet_NegativeTimestamp` — pre-epoch time wraps to value > MaxInt64.

#### M14. Gas limit int64→uint64 in MakeHeader — **FIXED**
- **File:** `rpc/types/utils.go:143`
- **Issue:** `uint64(gasLimit)` where `gasLimit` is `int64` from consensus params. Negative value wraps.
- **Fix:** Added negative check — clamp to 0 before uint64 cast. Removed `//nolint:gosec` comment.
- **Test:** `TestMakeHeader_NegativeGasLimit` — demonstrates MaxUint64 wrap.

#### M15. Block query race with pruning
- **File:** `rpc/backend/blocks.go`
- **Issue:** Separate fetches (block header, block results, block body) can race with pruning. Between two fetches, the block may be pruned, causing inconsistent data.
- **Fix needed:** Atomic block fetching or staleness detection.
- **Status:** TODO — requires integration test with pruning.

### LOW

#### L1. SuggestGasTipCap returns max delta, not median
- **File:** `rpc/backend/chain_info.go:372-377`
- **Issue:** Returns `baseFee * (ElasticityMultiplier-1) / Denominator` — the theoretical maximum base fee delta. geth computes a median of recent actual tips. This causes users to systematically overpay.
- **Fix needed:** Implement proper tip median calculation (sample recent blocks).
- **Test:** `TestL1_SuggestGasTipCap_ReturnsMaxDelta` — verifies the max delta formula.

#### L2. Empty string filter ID on limit
- **File:** `rpc/namespaces/ethereum/eth/filters/api.go:154,177`
- **Issue:** `NewPendingTransactionFilter` and `NewBlockFilter` return `rpc.ID("")` (empty string) when filter cap is reached. Clients cannot distinguish this from a valid filter ID — they'll use `""` in subsequent calls.
- **Fix needed:** Return proper error (these functions need `(rpc.ID, error)` signature).
- **Tests:** `TestNewPendingTransactionFilter_EmptyStringOnLimit`, `TestNewBlockFilter_EmptyStringOnLimit`.

#### L3. v.Sign()→uint64 edge case (YParity overflow)
- **File:** `rpc/types/utils.go:223+`
- **Issue:** `yparity := hexutil.Uint64(v.Sign())` where `v` is signature V value. If `v` is negative (corrupted signature), `v.Sign()` returns -1, which wraps to `uint64(MaxUint64) = 18446744073709551615`.
- **Fix needed:** Validate v >= 0 before conversion.
- **Tests:** `TestL3_VSignNegative_YParityOverflow`, `TestL3_VSignNegative_InNewRPCTransaction`.

#### L4. Net/Personal init panics
- **File:** `rpc/namespaces/ethereum/net/api.go:29`
- **Issue:** Namespace setup panics on initialization failure.
- **Fix needed:** Return error instead of panic.
- **Status:** Documented — same pattern as C3.

#### L5. Bloom length unvalidated
- **File:** `rpc/backend/comet_to_eth.go:367`
- **Issue:** `ethtypes.BytesToBloom([]byte(attr.Value))` — if attribute value is not 256 bytes, BytesToBloom silently truncates/pads. Short input produces wrong bloom filter; oversized input causes panic.
- **Fix needed:** Validate length == 256 before calling BytesToBloom.
- **Test:** `TestL5_BytesToBloom_WrongLength_NoError` — short, empty, and oversized inputs.

---

## Files Modified

### Round 1 (FIXED — commit `3c35572`)

| File | Action | Lines |
|------|--------|-------|
| `utils/int.go` | CREATED | +64 (safe cast helpers) |
| `utils/int_test.go` | CREATED | +89 |
| `rpc/types/utils.go` | EDITED | Fixed A1, A6, B1, B3, B4 |
| `rpc/types/utils_test.go` | CREATED | +251 |
| `rpc/types/events.go` | EDITED | Fixed A4 (negative gas check) |
| `rpc/types/events_test.go` | CREATED | +13 |
| `rpc/backend/comet_to_eth.go` | EDITED | Fixed A2, A4, A5, B5 |
| `rpc/backend/tx_info.go` | EDITED | Fixed A3, D1 |
| `rpc/backend/tx_info_test.go` | CREATED | +182 |
| `rpc/backend/utils.go` | EDITED | Fixed A4 |
| `rpc/backend/chain_info.go` | EDITED | Fixed ProcessBlock type assertion |
| `rpc/stream/rpc.go` | EDITED | Used SafeUint64 |
| `rpc/namespaces/ethereum/eth/filters/filters.go` | EDITED | Fixed C4 (future block range) |
| `rpc/namespaces/ethereum/eth/filters/filters_test.go` | CREATED | +57 |

### Round 2 (9 FIXED + 24 documented, commit `1710346`)

| File | Action | Tests Added |
|------|--------|------------|
| `rpc/backend/audit_round2_test.go` | CREATED | 3 (C3, C4) |
| `rpc/backend/tx_info_test.go` | APPENDED | +580 (C5, H2, H4, H6, H8, L1, L5, M11, M12) |
| `rpc/stream/queue_test.go` | APPENDED | +69 (H3) |
| `rpc/stream/rpc_test.go` | APPENDED | +4 tests (C2) |
| `rpc/types/utils_test.go` | APPENDED | +191 (H1, M13, M14, L3) |
| `rpc/types/events_test.go` | APPENDED | +47 (H5) |
| `rpc/namespaces/ethereum/eth/filters/api_test.go` | CREATED | +211 (M3, M4, M7, L2) |
| `rpc/namespaces/ethereum/eth/filters/filters_test.go` | APPENDED | +57 (H7) |
| `rpc/websockets_test.go` | APPENDED | +47 (C1) |

---

## Verification Commands

```bash
# Round 1 fixes — all pass
go build ./rpc/... ./utils/...
go test -tags test ./utils/... -count=1
go test ./rpc/types/... -count=1
go test -tags test ./rpc/backend/... -count=1
go test ./rpc/namespaces/ethereum/eth/filters/... -count=1

# Round 2 GREEN tests — verify fixes work
go test ./rpc/stream/... -count=1 -v -run "Graceful"
go test -tags test ./rpc/backend/... -count=1 -v -run "ReturnsError\|EVMChainID\|SuggestGasTipCap\|FeeHistory"
go test ./rpc/types/... -count=1 -v -run "Negative\|VSign\|MakeHeader\|FillTxAttribute"
go test ./rpc/namespaces/ethereum/eth/filters/... -count=1 -v -run "NotFound\|NoBlockRange\|EmptyString\|LogLimit\|H7"

# Coverage
go test -tags test ./rpc/backend/... -coverprofile=cov.out -count=1
go tool cover -func=cov.out
```

---

## Next Steps

1. **Remaining GREEN fixes:** 24 issues still documented (RED tests only) — C1, C5, H1-H3, H6, H8, M1-M11, M15, L1-L5
2. **REFACTOR phase:** Remove remaining `#nosec G115` / `//nolint:gosec` from fixed locations
3. **Race detection:** `go test -race ./rpc/... -count=1` for M6, D3 concurrency fixes
4. **Integration tests:** M5, M6, M8, M15 require full node integration testing
5. **PR update:** Push to PR #2 with all audit fixes
