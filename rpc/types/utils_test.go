package types_test

import (
	"context"
	"encoding/json"
	"math"
	"math/big"
	"testing"

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
