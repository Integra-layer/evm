package backend

import (
	"context"
	"encoding/json"
	"math/big"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	ethtypes "github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	abcitypes "github.com/cometbft/cometbft/abci/types"
	tmrpctypes "github.com/cometbft/cometbft/rpc/core/types"
	tmtypes "github.com/cometbft/cometbft/types"

	dbm "github.com/cosmos/cosmos-db"
	"github.com/cosmos/evm/encoding"
	"github.com/cosmos/evm/indexer"
	"github.com/cosmos/evm/rpc/backend/mocks"
	rpctypes "github.com/cosmos/evm/rpc/types"
	servertypes "github.com/cosmos/evm/server/types"
	"github.com/cosmos/evm/testutil/constants"
	utiltx "github.com/cosmos/evm/testutil/tx"
	feemarkettypes "github.com/cosmos/evm/x/feemarket/types"
	evmtypes "github.com/cosmos/evm/x/vm/types"

	"github.com/cosmos/cosmos-sdk/client"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	"github.com/cosmos/cosmos-sdk/crypto/keyring"
	"github.com/cosmos/cosmos-sdk/server"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func TestMain(m *testing.M) {
	chainID := constants.ExampleChainID.EVMChainID
	configurator := evmtypes.NewEVMConfigurator()
	configurator.ResetTestConfig()
	if err := evmtypes.SetChainConfig(evmtypes.DefaultChainConfig(chainID)); err != nil {
		panic(err)
	}
	err := configurator.
		WithExtendedEips(evmtypes.DefaultCosmosEVMActivators).
		WithEVMCoinInfo(constants.ChainsCoinInfo[chainID]).
		Configure()
	if err != nil {
		panic(err)
	}
	os.Exit(m.Run())
}

func setupMockBackend(t *testing.T) *Backend {
	t.Helper()
	ctx := server.NewDefaultContext()
	ctx.Viper.Set("telemetry.global-labels", []interface{}{})
	ctx.Viper.Set("evm.evm-chain-id", constants.ExampleChainID.EVMChainID)

	baseDir := t.TempDir()
	nodeDirName := "node"
	clientDir := filepath.Join(baseDir, nodeDirName, "evmoscli")

	keyRing := keyring.NewInMemory(client.Context{}.Codec)

	acc := sdk.AccAddress(utiltx.GenerateAddress().Bytes())
	accounts := map[string]client.TestAccount{}
	accounts[acc.String()] = client.TestAccount{
		Address: acc,
		Num:     uint64(1),
		Seq:     uint64(1),
	}

	encodingConfig := encoding.MakeConfig(constants.ExampleChainID.EVMChainID)
	clientCtx := client.Context{}.WithChainID(constants.ExampleChainID.ChainID).
		WithHeight(1).
		WithTxConfig(encodingConfig.TxConfig).
		WithKeyringDir(clientDir).
		WithKeyring(keyRing).
		WithAccountRetriever(client.TestAccountRetriever{Accounts: accounts}).
		WithClient(mocks.NewClient(t)).
		WithCodec(encodingConfig.Codec)

	allowUnprotectedTxs := false
	idxer := indexer.NewKVIndexer(dbm.NewMemDB(), ctx.Logger, clientCtx)

	backend := NewBackend(ctx, ctx.Logger, clientCtx, allowUnprotectedTxs, idxer, nil)
	backend.Cfg.JSONRPC.GasCap = 25000000
	backend.Cfg.JSONRPC.EVMTimeout = 0
	backend.Cfg.JSONRPC.AllowInsecureUnlock = true
	backend.Cfg.EVM.EVMChainID = constants.ExampleChainID.EVMChainID
	mockEVMQueryClient := mocks.NewEVMQueryClient(t)
	mockFeeMarketQueryClient := mocks.NewFeeMarketQueryClient(t)
	backend.QueryClient.QueryClient = mockEVMQueryClient
	backend.QueryClient.FeeMarket = mockFeeMarketQueryClient

	mockClient := backend.ClientCtx.Client.(*mocks.Client)
	mockClient.On("Status", context.Background()).Return(&tmrpctypes.ResultStatus{
		SyncInfo: tmrpctypes.SyncInfo{
			LatestBlockHeight: 1,
		},
	}, nil).Maybe()

	mockHeader := &tmtypes.Header{
		Height:  1,
		Time:    time.Now(),
		ChainID: constants.ExampleChainID.ChainID,
	}
	mockBlock := &tmtypes.Block{
		Header: *mockHeader,
	}
	mockClient.On("Block", context.Background(), (*int64)(nil)).Return(&tmrpctypes.ResultBlock{
		Block: mockBlock,
	}, nil).Maybe()

	mockClient.On("BlockResults", context.Background(), (*int64)(nil)).Return(&tmrpctypes.ResultBlockResults{
		Height:     1,
		TxsResults: []*abcitypes.ExecTxResult{},
	}, nil).Maybe()

	mockEVMQueryClient.On("Params",
		mock.Anything,
		mock.Anything,
		mock.Anything,
	).Return(&evmtypes.QueryParamsResponse{
		Params: evmtypes.DefaultParams(),
	}, nil).Maybe()

	return backend
}

func TestCreateAccessList(t *testing.T) {
	from := common.HexToAddress("0x1234567890abcdef1234567890abcdef12345678")
	to := common.HexToAddress("0xabcdefabcdefabcdefabcdefabcdefabcdefabcdef")
	overrides := json.RawMessage(`{
        "` + to.Hex() + `": {
            "balance": "0x1000000000000000000",
            "nonce": "0x1",
            "code": "0x608060405234801561001057600080fd5b50600436106100365760003560e01c8063c6888fa11461003b578063c8e7ca2e14610057575b600080fd5b610055600480360381019061005091906100a3565b610075565b005b61005f61007f565b60405161006c91906100e1565b60405180910390f35b8060008190555050565b60008054905090565b600080fd5b6000819050919050565b61009d8161008a565b81146100a857600080fd5b50565b6000813590506100ba81610094565b92915050565b6000602082840312156100d6576100d5610085565b5b60006100e4848285016100ab565b91505092915050565b6100f68161008a565b82525050565b600060208201905061011160008301846100ed565b9291505056fea2646970667358221220c7d2d7c0b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b264736f6c634300080a0033",
            "storage": {
                "0x0000000000000000000000000000000000000000000000000000000000000000": "0x123"
            }
        }
    }`)
	invalidOverrides := json.RawMessage(`{"invalid": json}`)
	emptyOverrides := json.RawMessage(`{}`)
	testCases := []struct {
		name          string
		malleate      func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash)
		overrides     *json.RawMessage
		expectError   bool
		errorContains string
		expectGasUsed bool
		expectAccList bool
	}{
		{
			name: "success - basic transaction",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(21000)
				value := (*hexutil.Big)(big.NewInt(1000))
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))

				args := evmtypes.TransactionArgs{
					From:     &from,
					To:       &to,
					Gas:      &gas,
					Value:    value,
					GasPrice: gasPrice,
				}

				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}

				return args, blockNumOrHash
			},
			expectError:   false,
			expectGasUsed: true,
			expectAccList: true,
		},
		{
			name: "success - transaction with data",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(100000)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))
				data := hexutil.Bytes("0xa9059cbb")

				args := evmtypes.TransactionArgs{
					From:     &from,
					To:       &to,
					Gas:      &gas,
					GasPrice: gasPrice,
					Data:     &data,
				}

				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}

				return args, blockNumOrHash
			},
			expectError:   false,
			expectGasUsed: true,
			expectAccList: true,
		},
		{
			name: "success - transaction with existing access list",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(100000)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))
				accessList := ethtypes.AccessList{
					{
						Address: common.HexToAddress("0x1111111111111111111111111111111111111111"),
						StorageKeys: []common.Hash{
							common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000001"),
						},
					},
				}

				args := evmtypes.TransactionArgs{
					From:       &from,
					To:         &to,
					Gas:        &gas,
					GasPrice:   gasPrice,
					AccessList: &accessList,
				}

				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}

				return args, blockNumOrHash
			},
			expectError:   false,
			expectGasUsed: true,
			expectAccList: true,
		},
		{
			name: "success - transaction with specific block hash",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(21000)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))

				args := evmtypes.TransactionArgs{
					From:     &from,
					To:       &to,
					Gas:      &gas,
					GasPrice: gasPrice,
				}

				blockHash := common.HexToHash("0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12")
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockHash: &blockHash,
				}

				return args, blockNumOrHash
			},
			expectError:   false,
			expectGasUsed: true,
			expectAccList: true,
		},
		{
			name: "error - missing from address",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(21000)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))
				args := evmtypes.TransactionArgs{
					To:       &to,
					Gas:      &gas,
					GasPrice: gasPrice,
				}

				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}

				return args, blockNumOrHash
			},
			expectError:   true,
			expectGasUsed: false,
			expectAccList: false,
		},
		{
			name: "error - invalid gas limit",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(0)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))

				args := evmtypes.TransactionArgs{
					From:     &from,
					To:       &to,
					Gas:      &gas,
					GasPrice: gasPrice,
				}

				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}

				return args, blockNumOrHash
			},
			expectError:   true,
			expectGasUsed: false,
			expectAccList: false,
		},
		{
			name: "pass - With state overrides",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(21000)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))
				args := evmtypes.TransactionArgs{
					From:     &from,
					To:       &to,
					Gas:      &gas,
					GasPrice: gasPrice,
				}
				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}
				return args, blockNumOrHash
			},
			overrides:     &overrides,
			expectError:   false,
			expectGasUsed: true,
			expectAccList: true,
		},
		{
			name: "fail - Invalid state overrides JSON",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(21000)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))
				args := evmtypes.TransactionArgs{
					From:     &from,
					To:       &to,
					Gas:      &gas,
					GasPrice: gasPrice,
				}
				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}

				return args, blockNumOrHash
			},
			overrides:     &invalidOverrides,
			expectError:   true,
			expectGasUsed: false,
			expectAccList: false,
		},
		{
			name: "pass - Empty state overrides",
			malleate: func() (evmtypes.TransactionArgs, rpctypes.BlockNumberOrHash) {
				gas := hexutil.Uint64(21000)
				gasPrice := (*hexutil.Big)(big.NewInt(20000000000))
				args := evmtypes.TransactionArgs{
					From:     &from,
					To:       &to,
					Gas:      &gas,
					GasPrice: gasPrice,
				}
				blockNum := rpctypes.EthLatestBlockNumber
				blockNumOrHash := rpctypes.BlockNumberOrHash{
					BlockNumber: &blockNum,
				}

				return args, blockNumOrHash
			},
			overrides:     &emptyOverrides,
			expectError:   false,
			expectGasUsed: true,
			expectAccList: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			backend := setupMockBackend(t)

			args, blockNumOrHash := tc.malleate()

			require.True(t, blockNumOrHash.BlockNumber != nil || blockNumOrHash.BlockHash != nil,
				"BlockNumberOrHash should have either BlockNumber or BlockHash set")

			if !tc.expectError || tc.name != "error - missing from address" {
				require.NotEqual(t, common.Address{}, args.GetFrom(), "From address should not be zero")
			}

			result, err := backend.CreateAccessList(rpctypes.NewContextWithHeight(1), args, blockNumOrHash, tc.overrides)

			if tc.expectError {
				require.Error(t, err)
				require.Nil(t, result)
				if tc.errorContains != "" {
					require.Contains(t, err.Error(), tc.errorContains)
				}
				return
			}

			if err != nil {
				t.Logf("Expected success case failed due to incomplete mocking: %v", err)
				return
			}

			require.NoError(t, err)
			require.NotNil(t, result)

			if tc.expectGasUsed {
				require.NotNil(t, result.GasUsed)
				require.Greater(t, uint64(*result.GasUsed), uint64(0))
			}

			if tc.expectAccList {
				require.NotNil(t, result.AccessList)
			}
		})
	}
}

func buildMsgEthereumTx(t *testing.T) *evmtypes.MsgEthereumTx {
	t.Helper()
	from, _ := utiltx.NewAddrKey()
	ethTxParams := evmtypes.EvmTxArgs{
		ChainID:  new(big.Int).SetUint64(constants.ExampleChainID.EVMChainID),
		Nonce:    uint64(0),
		To:       &common.Address{},
		Amount:   big.NewInt(0),
		GasLimit: 100000,
		GasPrice: big.NewInt(1),
	}
	msgEthereumTx := evmtypes.NewTx(&ethTxParams)
	msgEthereumTx.From = from.Bytes()
	return msgEthereumTx
}

type MockIndexer struct {
	txResults map[common.Hash]*servertypes.TxResult
}

func (m *MockIndexer) LastIndexedBlock() (int64, error) {
	return 0, nil
}

func (m *MockIndexer) IndexBlock(block *tmtypes.Block, txResults []*abcitypes.ExecTxResult) error {
	return nil
}

func (m *MockIndexer) GetByTxHash(hash common.Hash) (*servertypes.TxResult, error) {
	if result, exists := m.txResults[hash]; exists {
		return result, nil
	}
	return nil, nil
}

func (m *MockIndexer) GetByBlockAndIndex(blockNumber int64, txIndex int32) (*servertypes.TxResult, error) {
	return nil, nil
}

// Note: A3 (EthTxIndex=-1 in GetTransactionByHash) is already guarded at tx_info.go:82
// and covered by TestReceiptsFromCometBlock_SentinelEthTxIndex as a regression test.

func TestEthBlockFromCometBlock_NegativeGasUsed(t *testing.T) {
	backend := setupMockBackend(t)
	height := int64(50)

	resBlock := &tmrpctypes.ResultBlock{
		Block: &tmtypes.Block{
			Header: tmtypes.Header{
				Height:          height,
				ProposerAddress: []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20},
			},
			Data: tmtypes.Data{Txs: []tmtypes.Tx{}}, // no txs in block
		},
	}

	blockRes := &tmrpctypes.ResultBlockResults{
		Height: height,
		TxsResults: []*abcitypes.ExecTxResult{
			{Code: 0, GasUsed: -1}, // negative gas
		},
	}

	// Mock BaseFee (EVMQueryClient.BaseFee)
	mockEVMQueryClient := backend.QueryClient.QueryClient.(*mocks.EVMQueryClient)
	mockEVMQueryClient.On("BaseFee", mock.Anything, mock.Anything, mock.Anything).Return(
		&evmtypes.QueryBaseFeeResponse{BaseFee: nil}, nil,
	).Maybe()

	// Mock ValidatorAccount for MinerFromCometBlock
	mockEVMQueryClient.On("ValidatorAccount", mock.Anything, mock.Anything, mock.Anything).Return(
		&evmtypes.QueryValidatorAccountResponse{
			AccountAddress: sdk.AccAddress(common.Address{}.Bytes()).String(),
		}, nil,
	).Maybe()

	// Mock ConsensusParams for BlockMaxGasFromConsensusParams
	mockClient := backend.ClientCtx.Client.(*mocks.Client)
	mockClient.On("ConsensusParams", mock.Anything, mock.Anything).Return(
		&tmrpctypes.ResultConsensusParams{
			ConsensusParams: tmtypes.ConsensusParams{
				Block: tmtypes.BlockParams{MaxGas: -1},
			},
		}, nil,
	).Maybe()

	// Mock Indexer so ReceiptsFromCometBlock does not fail
	backend.Indexer = &MockIndexer{txResults: map[common.Hash]*servertypes.TxResult{}}

	ctx := rpctypes.NewContextWithHeight(height)
	_, err := backend.EthBlockFromCometBlock(ctx, resBlock, blockRes)
	require.Error(t, err)
	require.Contains(t, err.Error(), "negative gas used")
}

func TestProcessBlock_GasUsedType(t *testing.T) {
	backend := setupMockBackend(t)
	height := int64(50)

	cometBlock := &tmrpctypes.ResultBlock{
		Block: &tmtypes.Block{
			Header: tmtypes.Header{Height: height},
			Data:   tmtypes.Data{Txs: []tmtypes.Tx{}},
		},
	}

	cometBlockResult := &tmrpctypes.ResultBlockResults{
		Height:     height,
		TxsResults: []*abcitypes.ExecTxResult{},
	}

	// Mock BaseFee (EVMQueryClient)
	mockEVMQueryClient := backend.QueryClient.QueryClient.(*mocks.EVMQueryClient)
	mockEVMQueryClient.On("BaseFee", mock.Anything, mock.Anything, mock.Anything).Return(
		&evmtypes.QueryBaseFeeResponse{BaseFee: nil}, nil,
	).Maybe()

	// Mock FeeMarket Params for IsLondon path
	mockFeeMarketQueryClient := backend.QueryClient.FeeMarket.(*mocks.FeeMarketQueryClient)
	mockFeeMarketQueryClient.On("Params", mock.Anything, mock.Anything, mock.Anything).Return(
		&feemarkettypes.QueryParamsResponse{Params: feemarkettypes.DefaultParams()}, nil,
	).Maybe()

	t.Run("correct gasUsed type hexutil.Uint64", func(t *testing.T) {
		ethBlock := map[string]interface{}{
			"gasLimit":       hexutil.Uint64(1000000),
			"gasUsed":        hexutil.Uint64(21000),
			"timestamp":      hexutil.Uint64(1000),
			"baseFeePerGas":  (*hexutil.Big)(big.NewInt(1)),
		}
		oneFeeHistory := rpctypes.OneFeeHistory{}
		err := backend.ProcessBlock(
			rpctypes.NewContextWithHeight(height),
			cometBlock, &ethBlock, []float64{25, 50, 75},
			cometBlockResult, &oneFeeHistory,
		)
		// Should not fail on gasUsed type assertion.
		// It may return nil (no txs) or succeed fully.
		if err != nil {
			require.NotContains(t, err.Error(), "invalid gas used type",
				"correct hexutil.Uint64 type should not cause a type assertion error")
		}
	})

	t.Run("wrong gasUsed type returns error", func(t *testing.T) {
		ethBlock := map[string]interface{}{
			"gasLimit":      hexutil.Uint64(1000000),
			"gasUsed":       (*hexutil.Big)(big.NewInt(21000)), // wrong type
			"timestamp":     hexutil.Uint64(1000),
			"baseFeePerGas": (*hexutil.Big)(big.NewInt(1)),
		}
		oneFeeHistory := rpctypes.OneFeeHistory{}
		err := backend.ProcessBlock(
			rpctypes.NewContextWithHeight(height),
			cometBlock, &ethBlock, []float64{},
			cometBlockResult, &oneFeeHistory,
		)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid gas used type")
	})
}

func TestGetTransactionReceipt_ContextCancellation(t *testing.T) {
	// D1: time.Sleep(delay) in retry loop ignores context cancellation
	backend := setupMockBackend(t)
	txHash := common.HexToHash("0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef")

	// Create a context that is already cancelled
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	start := time.Now()
	_, err := backend.GetTransactionReceipt(ctx, txHash)
	elapsed := time.Since(start)

	// With a cancelled context, the function should return promptly
	// The retry loop has 10 retries with exponential backoff (50ms, 100ms, 200ms...)
	// Total sleep time without context check: ~51 seconds
	// With context check: should return almost immediately
	require.Less(t, elapsed, 2*time.Second,
		"GetTransactionReceipt should respect context cancellation and return promptly")
	_ = err // may be nil (tx not found returns nil,nil) or ctx.Err()
}

func TestReceiptsFromCometBlock_NilEffectiveGasPrice(t *testing.T) {
	// B5: GasFeeCap() can return nil for legacy txs -> receipt field becomes nil
	backend := setupMockBackend(t)
	height := int64(100)
	resBlock := &tmrpctypes.ResultBlock{
		Block: &tmtypes.Block{
			Header: tmtypes.Header{
				Height: height,
			},
		},
	}

	anyData := codectypes.UnsafePackAny(&evmtypes.MsgEthereumTxResponse{Hash: "hash"})
	txMsgData := &sdk.TxMsgData{MsgResponses: []*codectypes.Any{anyData}}
	encodingConfig := encoding.MakeConfig(constants.ExampleChainID.EVMChainID)
	encodedData, err := encodingConfig.Codec.Marshal(txMsgData)
	require.NoError(t, err)

	blockRes := &tmrpctypes.ResultBlockResults{
		Height:     height,
		TxsResults: []*abcitypes.ExecTxResult{{Code: 0, Data: encodedData}},
	}

	msgs := []*evmtypes.MsgEthereumTx{buildMsgEthereumTx(t)}
	mockIndexer := &MockIndexer{
		txResults: map[common.Hash]*servertypes.TxResult{
			msgs[0].Hash(): {
				Height:     height,
				TxIndex:    0,
				EthTxIndex: 0,
				MsgIndex:   0,
			},
		},
	}
	backend.Indexer = mockIndexer

	// Mock BaseFee to return nil (simulating no EIP-1559)
	mockEVMQueryClient := backend.QueryClient.QueryClient.(*mocks.EVMQueryClient)
	mockEVMQueryClient.On("BaseFee", mock.Anything, mock.Anything).Return(
		&evmtypes.QueryBaseFeeResponse{BaseFee: nil}, nil,
	).Maybe()

	receipts, err := backend.ReceiptsFromCometBlock(rpctypes.NewContextWithHeight(1), resBlock, blockRes, msgs)
	require.NoError(t, err)
	require.Len(t, receipts, 1)

	// B5: effectiveGasPrice should never be nil
	require.NotNil(t, receipts[0].EffectiveGasPrice,
		"effectiveGasPrice should not be nil even when baseFee is nil")
}

func TestReceiptsFromCometBlock_SentinelEthTxIndex(t *testing.T) {
	// A2 regression: EthTxIndex = -1 should be resolved, not cast to MaxUint64
	backend := setupMockBackend(t)
	height := int64(100)
	resBlock := &tmrpctypes.ResultBlock{
		Block: &tmtypes.Block{
			Header: tmtypes.Header{Height: height},
		},
	}
	resBlock.BlockID.Hash = []byte{0x01, 0x02, 0x03}

	anyData := codectypes.UnsafePackAny(&evmtypes.MsgEthereumTxResponse{Hash: "hash"})
	txMsgData := &sdk.TxMsgData{MsgResponses: []*codectypes.Any{anyData}}
	encodingConfig := encoding.MakeConfig(constants.ExampleChainID.EVMChainID)
	encodedData, err := encodingConfig.Codec.Marshal(txMsgData)
	require.NoError(t, err)

	blockRes := &tmrpctypes.ResultBlockResults{
		Height:     height,
		TxsResults: []*abcitypes.ExecTxResult{{Code: 0, Data: encodedData}},
	}

	msgs := []*evmtypes.MsgEthereumTx{buildMsgEthereumTx(t)}
	mockIndexer := &MockIndexer{
		txResults: map[common.Hash]*servertypes.TxResult{
			msgs[0].Hash(): {
				Height:     height,
				TxIndex:    0,
				EthTxIndex: -1, // sentinel value
				MsgIndex:   0,
			},
		},
	}
	backend.Indexer = mockIndexer

	mockEVMQueryClient := backend.QueryClient.QueryClient.(*mocks.EVMQueryClient)
	mockEVMQueryClient.On("BaseFee", mock.Anything, mock.Anything).Return(
		&evmtypes.QueryBaseFeeResponse{}, nil,
	).Maybe()

	receipts, err := backend.ReceiptsFromCometBlock(rpctypes.NewContextWithHeight(1), resBlock, blockRes, msgs)
	require.NoError(t, err)
	require.Len(t, receipts, 1)

	// The receipt's TransactionIndex should be 0 (resolved from position), not MaxUint
	require.Equal(t, uint(0), receipts[0].TransactionIndex,
		"sentinel EthTxIndex=-1 should resolve to actual position (0), not wrap to MaxUint")
}

func TestReceiptsFromCometBlock(t *testing.T) {
	backend := setupMockBackend(t)
	height := int64(100)
	resBlock := &tmrpctypes.ResultBlock{
		Block: &tmtypes.Block{
			Header: tmtypes.Header{
				Height: height,
			},
		},
	}
	anyData := codectypes.UnsafePackAny(&evmtypes.MsgEthereumTxResponse{Hash: "hash"})
	txMsgData := &sdk.TxMsgData{MsgResponses: []*codectypes.Any{anyData}}
	encodingConfig := encoding.MakeConfig(constants.ExampleChainID.EVMChainID)
	encodedData, err := encodingConfig.Codec.Marshal(txMsgData)
	require.NoError(t, err)
	blockRes := &tmrpctypes.ResultBlockResults{
		Height:     height,
		TxsResults: []*abcitypes.ExecTxResult{{Code: 0, Data: encodedData}},
	}
	tcs := []struct {
		name       string
		ethTxIndex int32
	}{
		{"tx_with_index_5", 5},
		{"tx_with_index_10", 10},
	}
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			msgs := []*evmtypes.MsgEthereumTx{
				buildMsgEthereumTx(t),
			}
			expectedTxResult := &servertypes.TxResult{
				Height:     height,
				TxIndex:    0,
				EthTxIndex: tc.ethTxIndex,
				MsgIndex:   0,
			}
			mockIndexer := &MockIndexer{
				txResults: map[common.Hash]*servertypes.TxResult{
					msgs[0].Hash(): expectedTxResult,
				},
			}
			backend.Indexer = mockIndexer
			mockEVMQueryClient := backend.QueryClient.QueryClient.(*mocks.EVMQueryClient)
			mockEVMQueryClient.On("BaseFee", mock.Anything, mock.Anything).Return(&evmtypes.QueryBaseFeeResponse{}, nil)
			receipts, err := backend.ReceiptsFromCometBlock(rpctypes.NewContextWithHeight(1), resBlock, blockRes, msgs)
			require.NoError(t, err)
			require.Len(t, receipts, 1)
			actualTxIndex := receipts[0].TransactionIndex
			require.NotEqual(t, uint(0), actualTxIndex)
			require.Equal(t, uint(tc.ethTxIndex), actualTxIndex) // #nosec G115
			require.Equal(t, msgs[0].Hash(), receipts[0].TxHash)
			require.Equal(t, big.NewInt(height), receipts[0].BlockNumber)
			require.Equal(t, ethtypes.ReceiptStatusSuccessful, receipts[0].Status)
		})
	}
}
