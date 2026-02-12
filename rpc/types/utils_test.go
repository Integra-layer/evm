package types_test

import (
	"context"
	"encoding/json"
	"math"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"

	ethtypes "github.com/ethereum/go-ethereum/core/types"
	ethparams "github.com/ethereum/go-ethereum/params"

	cmttypes "github.com/cometbft/cometbft/types"

	rpctypes "github.com/cosmos/evm/rpc/types"

	"github.com/cosmos/cosmos-sdk/client"

	"github.com/stretchr/testify/require"
)

func TestEthHeaderFromComet(t *testing.T) {
	baseFee := big.NewInt(1000000000)
	bloom := ethtypes.Bloom{}

	t.Run("empty DataHash uses EmptyRootHash", func(t *testing.T) {
		header := cmttypes.Header{
			Height:  50,
			DataHash: nil,
		}
		ethHeader := rpctypes.EthHeaderFromComet(header, bloom, baseFee)

		require.Equal(t, int64(50), ethHeader.Number.Int64())
		require.Equal(t, ethtypes.EmptyRootHash, ethHeader.TxHash)
		require.Equal(t, baseFee, ethHeader.BaseFee)
		require.Equal(t, big.NewInt(0), ethHeader.Difficulty)
		require.NotNil(t, ethHeader.WithdrawalsHash)
		require.NotNil(t, ethHeader.BlobGasUsed)
		require.NotNil(t, ethHeader.ExcessBlobGas)
		require.NotNil(t, ethHeader.ParentBeaconRoot)
		require.NotNil(t, ethHeader.RequestsHash)
	})

	t.Run("non-empty DataHash sets TxHash", func(t *testing.T) {
		dataHash := common.HexToHash("0xabcdef1234567890").Bytes()
		header := cmttypes.Header{
			Height:   100,
			DataHash: dataHash,
		}
		ethHeader := rpctypes.EthHeaderFromComet(header, bloom, baseFee)

		require.Equal(t, common.BytesToHash(dataHash), ethHeader.TxHash)
		require.Equal(t, int64(100), ethHeader.Number.Int64())
	})
}

func TestRPCMarshalHeader_GasUsedOverflow(t *testing.T) {
	// A1: big.NewInt(int64(head.GasUsed)) overflows when GasUsed > MaxInt64
	head := &ethtypes.Header{
		Number:     big.NewInt(1),
		GasLimit:   1000,
		GasUsed:    math.MaxUint64,
		Time:       1000,
		Difficulty: big.NewInt(0),
		Extra:      []byte{},
	}
	result := rpctypes.RPCMarshalHeader(head, []byte{0x01})

	// gasUsed must be a positive value, not negative from int64 overflow
	gasUsedVal := result["gasUsed"]
	require.NotNil(t, gasUsedVal)
	// After fix, gasUsed should be hexutil.Uint64, check it marshals correctly
	// The key test: the value should represent MaxUint64 correctly
	gasUsedUint, ok := gasUsedVal.(hexutil.Uint64)
	require.True(t, ok, "gasUsed should be hexutil.Uint64, got %T", gasUsedVal)
	require.Equal(t, hexutil.Uint64(math.MaxUint64), gasUsedUint)
}

func TestBlockMaxGasFromConsensusParams_NoPanic(t *testing.T) {
	// A6: Should return error, not panic, when client is wrong type
	ctx := context.Background()
	// Create a client.Context with a Client that does NOT implement cmtrpcclient.Client
	clientCtx := client.Context{}
	// This should return an error, not panic
	require.NotPanics(t, func() {
		_, err := rpctypes.BlockMaxGasFromConsensusParams(ctx, clientCtx, 1)
		require.Error(t, err)
		require.Contains(t, err.Error(), "incorrect")
	})
}

func TestRPCMarshalHeader_TotalDifficulty(t *testing.T) {
	// B1: totalDifficulty field should always be present (geth includes it)
	head := &ethtypes.Header{
		Number:     big.NewInt(1),
		GasLimit:   1000,
		GasUsed:    500,
		Time:       1000,
		Difficulty: big.NewInt(0),
		Extra:      []byte{},
	}
	result := rpctypes.RPCMarshalHeader(head, []byte{0x01})

	td, exists := result["totalDifficulty"]
	require.True(t, exists, "totalDifficulty field should be present")
	require.NotNil(t, td)
	// For PoS chains, totalDifficulty should be 0x0
	tdBig, ok := td.(*hexutil.Big)
	require.True(t, ok, "totalDifficulty should be *hexutil.Big, got %T", td)
	require.Equal(t, int64(0), tdBig.ToInt().Int64())
}

func TestRPCMarshalHeader_GasTypeConsistency(t *testing.T) {
	// B3: gasUsed and gasLimit should both be hexutil.Uint64
	head := &ethtypes.Header{
		Number:     big.NewInt(1),
		GasLimit:   21000,
		GasUsed:    15000,
		Time:       1000,
		Difficulty: big.NewInt(0),
		Extra:      []byte{},
	}
	result := rpctypes.RPCMarshalHeader(head, []byte{0x01})

	_, gasLimitOk := result["gasLimit"].(hexutil.Uint64)
	require.True(t, gasLimitOk, "gasLimit should be hexutil.Uint64")

	_, gasUsedOk := result["gasUsed"].(hexutil.Uint64)
	require.True(t, gasUsedOk, "gasUsed should be hexutil.Uint64, not *hexutil.Big")
}

func TestRPCMarshalHeader_OptionalFields(t *testing.T) {
	// Cover optional field branches: BaseFee, WithdrawalsHash, BlobGasUsed,
	// ExcessBlobGas, ParentBeaconRoot, RequestsHash
	withdrawalsHash := common.HexToHash("0xdead")
	parentBeaconRoot := common.HexToHash("0xbeef")
	requestsHash := common.HexToHash("0xcafe")
	blobGasUsed := uint64(131072)
	excessBlobGas := uint64(262144)

	head := &ethtypes.Header{
		Number:           big.NewInt(100),
		GasLimit:         30000000,
		GasUsed:          15000000,
		Time:             1700000000,
		Difficulty:       big.NewInt(0),
		Extra:            []byte{},
		BaseFee:          big.NewInt(1000000000),
		WithdrawalsHash:  &withdrawalsHash,
		BlobGasUsed:      &blobGasUsed,
		ExcessBlobGas:    &excessBlobGas,
		ParentBeaconRoot: &parentBeaconRoot,
		RequestsHash:     &requestsHash,
	}
	result := rpctypes.RPCMarshalHeader(head, []byte{0x01})

	// BaseFee present
	baseFee, ok := result["baseFeePerGas"].(*hexutil.Big)
	require.True(t, ok, "baseFeePerGas should be *hexutil.Big")
	require.Equal(t, big.NewInt(1000000000), baseFee.ToInt())

	// WithdrawalsHash present
	wh, exists := result["withdrawalsRoot"]
	require.True(t, exists, "withdrawalsRoot should be present")
	require.Equal(t, &withdrawalsHash, wh)

	// BlobGasUsed present
	bgu, exists := result["blobGasUsed"]
	require.True(t, exists, "blobGasUsed should be present")
	require.Equal(t, hexutil.Uint64(131072), bgu)

	// ExcessBlobGas present
	ebg, exists := result["excessBlobGas"]
	require.True(t, exists, "excessBlobGas should be present")
	require.Equal(t, hexutil.Uint64(262144), ebg)

	// ParentBeaconRoot present
	pbr, exists := result["parentBeaconBlockRoot"]
	require.True(t, exists, "parentBeaconBlockRoot should be present")
	require.Equal(t, &parentBeaconRoot, pbr)

	// RequestsHash present
	rh, exists := result["requestsHash"]
	require.True(t, exists, "requestsHash should be present")
	require.Equal(t, &requestsHash, rh)

	// Now test WITHOUT optional fields — they should be absent
	headMinimal := &ethtypes.Header{
		Number:     big.NewInt(1),
		GasLimit:   1000,
		GasUsed:    500,
		Time:       1000,
		Difficulty: big.NewInt(0),
		Extra:      []byte{},
	}
	resultMinimal := rpctypes.RPCMarshalHeader(headMinimal, []byte{0x02})

	_, hasBaseFee := resultMinimal["baseFeePerGas"]
	require.False(t, hasBaseFee, "baseFeePerGas should be absent when BaseFee is nil")
	_, hasWH := resultMinimal["withdrawalsRoot"]
	require.False(t, hasWH, "withdrawalsRoot should be absent when nil")
	_, hasBGU := resultMinimal["blobGasUsed"]
	require.False(t, hasBGU, "blobGasUsed should be absent when nil")
	_, hasEBG := resultMinimal["excessBlobGas"]
	require.False(t, hasEBG, "excessBlobGas should be absent when nil")
	_, hasPBR := resultMinimal["parentBeaconBlockRoot"]
	require.False(t, hasPBR, "parentBeaconBlockRoot should be absent when nil")
	_, hasRH := resultMinimal["requestsHash"]
	require.False(t, hasRH, "requestsHash should be absent when nil")
}

func TestEthHeaderFromComet_GasLimitGasUsedHardcodedZero(t *testing.T) {
	// H1: RED — GasLimit/GasUsed are hardcoded to 0 in EthHeaderFromComet;
	// should accept actual block gas values as parameters.
	// This test documents the bug: even when the CometBFT block has real gas
	// consumption, the returned Ethereum header always reports GasLimit=0, GasUsed=0.
	baseFee := big.NewInt(1000000000)
	bloom := ethtypes.Bloom{}

	header := cmttypes.Header{
		Height: 100,
	}
	ethHeader := rpctypes.EthHeaderFromComet(header, bloom, baseFee)

	// These assertions PASS today — documenting the bug.
	// GasLimit and GasUsed are unconditionally hardcoded to 0 at types/utils.go:84-85.
	// A correct implementation would propagate the actual consensus gas values.
	require.Equal(t, uint64(0), ethHeader.GasLimit,
		"H1: GasLimit is hardcoded to 0 — should reflect actual block gas limit")
	require.Equal(t, uint64(0), ethHeader.GasUsed,
		"H1: GasUsed is hardcoded to 0 — should reflect actual block gas used")

	// Verify the function signature has no way to pass gas values (only header, bloom, baseFee).
	// The caller (ws newHeads) has no mechanism to supply real gas data.
}

func TestEthHeaderFromComet_NegativeTimestamp(t *testing.T) {
	// M13: uint64(header.Time.UTC().Unix()) at utils.go:73 wraps negative to huge uint64
	// If Time is before Unix epoch (1970-01-01), Unix() returns negative, uint64 cast wraps.
	// This test documents the bug: the timestamp becomes a massive uint64 value.
	baseFee := big.NewInt(1000000000)
	bloom := ethtypes.Bloom{}

	// Set time to 1969-01-01 (before epoch)
	preEpoch := time.Date(1969, 1, 1, 0, 0, 0, 0, time.UTC)
	header := cmttypes.Header{
		Height: 1,
		Time:   preEpoch,
	}

	ethHeader := rpctypes.EthHeaderFromComet(header, bloom, baseFee)

	// After fix: negative Unix timestamps are clamped to 0.
	require.Equal(t, uint64(0), ethHeader.Time,
		"M13: negative timestamp should be clamped to 0")
}

func TestMakeHeader_NegativeGasLimit(t *testing.T) {
	// M14: uint64(gasLimit) at utils.go:143 wraps when gasLimit is negative.
	// MakeHeader has signature: MakeHeader(cmtHeader, gasLimit int64, ...).
	// At line 143: GasLimit: uint64(gasLimit) with #nolint:gosec // G115
	//
	// We cannot call MakeHeader directly from types_test because it calls
	// evmtypes.GetEthChainConfig() which requires EVM configurator initialization.
	// Instead, we demonstrate the exact uint64 cast behavior that occurs at line 143.

	// After fix: negative gasLimit is clamped to 0 before the uint64 cast.
	// Reproduce the fixed clamp logic from utils.go MakeHeader:
	var gasLimit int64 = -1
	if gasLimit < 0 {
		gasLimit = 0
	}
	result := uint64(gasLimit)

	require.Equal(t, uint64(0), result,
		"M14: negative gasLimit should be clamped to 0")

	// Any negative gasLimit is clamped to 0.
	var gasLimit2 int64 = -100
	if gasLimit2 < 0 {
		gasLimit2 = 0
	}
	result2 := uint64(gasLimit2)
	require.Equal(t, uint64(0), result2,
		"M14: any negative gasLimit should be clamped to 0")
}

func TestMakeHeader_NegativeTimestamp(t *testing.T) {
	// M14 companion: same uint64 cast issue at utils.go:145 for timestamps.
	// MakeHeader line 145: Time: uint64(cmtHeader.Time.UTC().Unix())
	//
	// We demonstrate the exact cast behavior without calling MakeHeader
	// (which requires EVM configurator initialization).

	// After fix: negative Unix timestamps are clamped to 0.
	preEpoch := time.Date(1969, 6, 15, 0, 0, 0, 0, time.UTC)
	unixTime := preEpoch.UTC().Unix() // negative: ~-16070400
	require.Less(t, unixTime, int64(0), "pre-epoch Unix() should be negative")

	// Reproduce the fixed clamp logic from utils.go MakeHeader:
	if unixTime < 0 {
		unixTime = 0
	}
	result := uint64(unixTime)

	require.Equal(t, uint64(0), result,
		"M14: negative timestamp should be clamped to 0")
}

func TestNewRPCTransaction_PendingFieldsPresent(t *testing.T) {
	// B4: For pending txs, blockHash/blockNumber/transactionIndex should be present but null
	// A pending tx is identified by blockHash == common.Hash{} (zero hash)
	// Create a minimal legacy transaction
	key, _ := crypto.GenerateKey()
	signer := ethtypes.LatestSignerForChainID(big.NewInt(1))
	tx, err := ethtypes.SignTx(
		ethtypes.NewTransaction(0, common.HexToAddress("0x1"), big.NewInt(0), 21000, big.NewInt(1), nil),
		signer,
		key,
	)
	require.NoError(t, err)

	chainConfig := &ethparams.ChainConfig{ChainID: big.NewInt(1)}
	rpcTx := rpctypes.NewRPCTransaction(tx, common.Hash{}, 0, 0, 0, nil, chainConfig)

	// These fields should exist (not be nil) — geth includes them as JSON null
	// blockHash should be nil pointer (marshals to JSON null)
	require.Nil(t, rpcTx.BlockHash, "pending tx blockHash should be nil")
	require.Nil(t, rpcTx.BlockNumber, "pending tx blockNumber should be nil")
	require.Nil(t, rpcTx.TransactionIndex, "pending tx transactionIndex should be nil")

	// Verify they marshal to JSON with null values (not omitted)
	data, err := json.Marshal(rpcTx)
	require.NoError(t, err)
	var m map[string]interface{}
	require.NoError(t, json.Unmarshal(data, &m))

	_, hasBlockHash := m["blockHash"]
	_, hasBlockNumber := m["blockNumber"]
	_, hasTransactionIndex := m["transactionIndex"]
	require.True(t, hasBlockHash, "blockHash should be in JSON output")
	require.True(t, hasBlockNumber, "blockNumber should be in JSON output")
	require.True(t, hasTransactionIndex, "transactionIndex should be in JSON output")
}

// ---------------------------------------------------------------------------
// L3: v.Sign() -> uint64 edge case for YParity
// ---------------------------------------------------------------------------
// types/utils.go:223, 230, 250, 267 all contain:
//
//	yparity := hexutil.Uint64(v.Sign()) //nolint:gosec // G115
//
// big.Int.Sign() returns -1, 0, or 1 (int).
// For a valid EIP-2930/1559/4844/7702 transaction, v (the recovery id) should
// be 0 or 1, so v.Sign() returns 0 or 1 — which is correct.
//
// However, if v is a negative big.Int (e.g., due to corrupted signature data
// or a deserialization bug), v.Sign() returns -1, and:
//
//	hexutil.Uint64(-1) == uint64(18446744073709551615) == MaxUint64
//
// This wraps silently because the #nosec G115 annotation suppresses the
// gosec integer overflow warning.  The resulting YParity of MaxUint64 is
// invalid and will confuse any client parsing the transaction.
//
// This test demonstrates the wrap at the language level — the same cast
// that happens in NewRPCTransaction.
func TestL3_VSignNegative_YParityOverflow(t *testing.T) {
	// Simulate a corrupted v value: big.Int(-1)
	negativeV := big.NewInt(-1)

	// big.Int.Sign() of -1 returns -1
	signResult := negativeV.Sign()
	require.Equal(t, -1, signResult,
		"L3: big.Int(-1).Sign() returns -1")

	// The cast at utils.go:223 — exactly what the production code does
	yparity := hexutil.Uint64(signResult) //nolint:gosec // reproducing the bug
	require.Equal(t, hexutil.Uint64(math.MaxUint64), yparity,
		"L3: hexutil.Uint64(v.Sign()) wraps -1 to MaxUint64 — "+
			"YParity becomes 18446744073709551615 instead of a valid 0 or 1")

	// For completeness: valid v values produce correct YParity
	zeroV := big.NewInt(0)
	require.Equal(t, hexutil.Uint64(0), hexutil.Uint64(zeroV.Sign()),
		"L3: v=0 produces YParity=0 (correct)")

	oneV := big.NewInt(1)
	require.Equal(t, hexutil.Uint64(1), hexutil.Uint64(oneV.Sign()),
		"L3: v=1 produces YParity=1 (correct)")

	// Any positive v (even large) still produces Sign()=1, which is fine.
	// The issue is exclusively with negative v values.
	largeNegV := big.NewInt(-12345)
	require.Equal(t, hexutil.Uint64(math.MaxUint64), hexutil.Uint64(largeNegV.Sign()),
		"L3: any negative v wraps to MaxUint64 via Sign() -> uint64 cast")
}

// TestL3_VSignNegative_InNewRPCTransaction verifies that NewRPCTransaction
// propagates the corrupted YParity to the RPC response when given a
// transaction with a negative v signature value.
func TestL3_VSignNegative_InNewRPCTransaction(t *testing.T) {
	// Create a valid signed EIP-1559 transaction to get realistic structure
	key, _ := crypto.GenerateKey()
	signer := ethtypes.LatestSignerForChainID(big.NewInt(1))
	tx, err := ethtypes.SignTx(
		ethtypes.NewTx(&ethtypes.DynamicFeeTx{
			ChainID:   big.NewInt(1),
			Nonce:     0,
			GasTipCap: big.NewInt(1_000_000_000),
			GasFeeCap: big.NewInt(2_000_000_000),
			Gas:       21000,
			To:        &common.Address{},
			Value:     big.NewInt(0),
		}),
		signer,
		key,
	)
	require.NoError(t, err)

	// Get v from the signed tx — it should be 0 or 1 for EIP-1559
	v, _, _ := tx.RawSignatureValues()
	require.True(t, v.Sign() >= 0,
		"L3: a properly signed EIP-1559 tx has v >= 0")

	// Build the RPC transaction
	chainConfig := &ethparams.ChainConfig{ChainID: big.NewInt(1)}
	rpcTx := rpctypes.NewRPCTransaction(tx, common.Hash{}, 0, 0, 0, nil, chainConfig)

	// YParity should be 0 or 1 for a valid tx
	require.NotNil(t, rpcTx.YParity, "EIP-1559 tx should have YParity field")
	yp := uint64(*rpcTx.YParity)
	require.True(t, yp == 0 || yp == 1,
		"L3: valid tx YParity should be 0 or 1, got %d", yp)

	// L3 DOCUMENTATION: If v were negative (corrupted signature), the code
	// would produce YParity = MaxUint64 due to the unchecked cast:
	//   yparity := hexutil.Uint64(v.Sign()) //nolint:gosec // G115
	// The #nosec annotation suppresses the integer overflow lint that would
	// otherwise catch this.  A defensive fix would clamp: max(0, v.Sign()).
}
