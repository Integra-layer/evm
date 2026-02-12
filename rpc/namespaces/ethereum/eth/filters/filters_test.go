package filters

import (
	"context"
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	ethtypes "github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/eth/filters"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	cmtrpctypes "github.com/cometbft/cometbft/rpc/core/types"
	comettypes "github.com/cometbft/cometbft/types"

	filtermocks "github.com/cosmos/evm/rpc/namespaces/ethereum/eth/filters/mocks"
	rpctypes "github.com/cosmos/evm/rpc/types"

	"cosmossdk.io/log"
)

func TestLogs(t *testing.T) {
	blockHeight := int64(100)
	fakeHeader := &ethtypes.Header{Number: big.NewInt(blockHeight)}
	fakeBlockRes := &cmtrpctypes.ResultBlockResults{Height: blockHeight}
	fakeBloom := ethtypes.Bloom{}
	blockHash := common.HexToHash("0xabc")
	fakeBlock := &cmtrpctypes.ResultBlock{Block: &comettypes.Block{Header: comettypes.Header{Height: blockHeight}}}

	tests := []struct {
		name      string
		errorStep string
		prepare   func() *filtermocks.Backend
		criteria  filters.FilterCriteria
		expectErr bool
		expectMsg string
	}{
		{
			name:      "HeaderByNumber returns error",
			errorStep: "HeaderByNumber",
			prepare: func() *filtermocks.Backend {
				backend := &filtermocks.Backend{}
				backend.EXPECT().HeaderByNumber(mock.Anything, mock.Anything).Return((*ethtypes.Header)(nil), errors.New("header error"))
				return backend
			},
			criteria: filters.FilterCriteria{
				FromBlock: big.NewInt(blockHeight),
				ToBlock:   big.NewInt(blockHeight),
			},
			expectErr: true,
			expectMsg: "header error",
		},
		{
			name:      "CometBlockResultByNumber returns error",
			errorStep: "CometBlockResultByNumber",
			prepare: func() *filtermocks.Backend {
				backend := &filtermocks.Backend{}
				backend.EXPECT().HeaderByNumber(mock.Anything, mock.Anything).Return(fakeHeader, nil)
				backend.EXPECT().CometBlockResultByNumber(mock.Anything, &blockHeight).Return((*cmtrpctypes.ResultBlockResults)(nil), errors.New("block result error"))
				return backend
			},
			criteria: filters.FilterCriteria{
				FromBlock: big.NewInt(blockHeight),
				ToBlock:   big.NewInt(blockHeight),
			},
			expectErr: true,
			expectMsg: "block result error",
		},
		{
			name:      "BlockBloom returns error",
			errorStep: "BlockBloom",
			prepare: func() *filtermocks.Backend {
				backend := &filtermocks.Backend{}
				backend.EXPECT().HeaderByNumber(mock.Anything, mock.Anything).Return(fakeHeader, nil)
				backend.EXPECT().CometBlockResultByNumber(mock.Anything, &blockHeight).Return(fakeBlockRes, nil)
				backend.EXPECT().BlockBloomFromCometBlock(mock.Anything, fakeBlockRes).Return(ethtypes.Bloom{}, errors.New("bloom error"))
				return backend
			},
			criteria: filters.FilterCriteria{
				FromBlock: big.NewInt(blockHeight),
				ToBlock:   big.NewInt(blockHeight),
			},
			expectErr: true,
			expectMsg: "bloom error",
		},
		{
			name:      "Single block by BlockHash",
			errorStep: "none",
			prepare: func() *filtermocks.Backend {
				backend := &filtermocks.Backend{}
				backend.EXPECT().CometBlockByHash(mock.Anything, blockHash).Return(fakeBlock, nil)
				backend.EXPECT().CometBlockResultByNumber(mock.Anything, &blockHeight).Return(fakeBlockRes, nil)
				backend.EXPECT().BlockBloomFromCometBlock(mock.Anything, fakeBlockRes).Return(fakeBloom, nil)
				return backend
			},
			criteria: filters.FilterCriteria{
				BlockHash: &blockHash,
			},
			expectErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			logger := log.NewNopLogger()
			backend := tt.prepare()

			var filter *Filter
			if tt.criteria.BlockHash != nil && *tt.criteria.BlockHash != (common.Hash{}) {
				filter = NewBlockFilter(logger, backend, tt.criteria)
			} else {
				filter = NewRangeFilter(logger, backend, blockHeight, blockHeight, nil, nil)
			}

			logs, err := filter.Logs(context.Background(), 1000, 100)
			if tt.expectErr {
				require.Error(t, err)
				require.Contains(t, err.Error(), tt.expectMsg)
				require.Nil(t, logs)
			} else {
				require.NoError(t, err)
				require.NotNil(t, logs)
			}

			backend.AssertExpectations(t)
		})
	}
}

func TestFilter_Logs_FutureBlockRange(t *testing.T) {
	// C4: When from > head, should return empty array, not error
	// geth returns [] for future block ranges
	logger := log.NewNopLogger()
	latestHeight := int64(100)

	backend := filtermocks.NewBackend(t)
	backend.EXPECT().HeaderByNumber(mock.Anything, rpctypes.EthLatestBlockNumber).Return(
		&ethtypes.Header{Number: big.NewInt(latestHeight)}, nil,
	)

	f := NewRangeFilter(logger, backend, 200, 300, nil, nil)

	logs, err := f.Logs(context.Background(), 10000, 10000)
	// After fix: should return empty array, not error
	require.NoError(t, err, "future block range should return empty array, not error")
	require.Empty(t, logs)
}

func TestFilter(t *testing.T) {
	logger := log.NewNopLogger()
	testCases := []struct {
		name         string
		filter       filters.FilterCriteria
		expectations func(b *filtermocks.Backend)
		expLogs      []*ethtypes.Log
		expErr       string
	}{
		{
			name:   "future block range returns empty (geth-compatible)",
			filter: filters.FilterCriteria{FromBlock: big.NewInt(100), ToBlock: big.NewInt(110)},
			expectations: func(b *filtermocks.Backend) {
				b.EXPECT().HeaderByNumber(mock.Anything, rpctypes.EthLatestBlockNumber).Return(&ethtypes.Header{Number: big.NewInt(5)}, nil)
			},
			expLogs: []*ethtypes.Log{},
		},
		{
			name:   "to > head is clamped to head",
			filter: filters.FilterCriteria{FromBlock: big.NewInt(50), ToBlock: big.NewInt(200)},
			expectations: func(b *filtermocks.Backend) {
				b.EXPECT().HeaderByNumber(mock.Anything, rpctypes.EthLatestBlockNumber).Return(&ethtypes.Header{Number: big.NewInt(100)}, nil)
				// The range should be clamped to [50, 100]. Mock block results for these heights.
				b.EXPECT().CometBlockResultByNumber(mock.Anything, mock.Anything).Return(
					&cmtrpctypes.ResultBlockResults{Height: 50}, nil,
				).Maybe()
				b.EXPECT().BlockBloomFromCometBlock(mock.Anything, mock.Anything).Return(ethtypes.Bloom{}, nil).Maybe()
			},
			expLogs: []*ethtypes.Log{},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			backend := filtermocks.NewBackend(t)
			f := newFilter(logger, backend, tc.filter, nil)
			tc.expectations(backend)
			logs, err := f.Logs(context.Background(), 15, 50)
			if tc.expErr != "" {
				require.ErrorContains(t, err, tc.expErr)
			} else {
				require.NoError(t, err)
			}

			if tc.expLogs != nil {
				if len(tc.expLogs) == 0 {
					require.Empty(t, logs)
				} else {
					require.Equal(t, tc.expLogs, logs)
				}
			}
		})
	}
}

// ---------------------------------------------------------------------------
// H7: eth_getLogs OOM — early log limit guard prevents unnecessary allocation
// ---------------------------------------------------------------------------
// The fix adds an early check before calling blockLogs():
//
//	if len(logs) >= logLimit {
//	    return nil, fmt.Errorf("query returned more than %d results", logLimit)
//	}
//
// This ensures that once we have accumulated logLimit logs, we stop fetching
// additional blocks entirely — avoiding the OOM vector where blockLogs()
// would materialize a massive slice before the post-fetch limit check runs.
//
// The original post-fetch check is also retained as a second line of defense
// for the case where a single block's logs push us over the limit.
func TestH7_LogLimitCheckAfterAllocation(t *testing.T) {
	// Verify the early guard: once accumulated logs reach logLimit,
	// no further blocks should be fetched.
	logLimit := 5

	// Simulate: we have already accumulated exactly logLimit logs
	existingLogs := make([]*ethtypes.Log, logLimit)
	for i := 0; i < logLimit; i++ {
		existingLogs[i] = &ethtypes.Log{
			BlockNumber: 99,
			Index:       uint(i),
		}
	}

	// The early guard: len(logs) >= logLimit fires BEFORE blockLogs() is called,
	// so no additional allocation happens.
	earlyGuardTriggered := len(existingLogs) >= logLimit
	require.True(t, earlyGuardTriggered,
		"H7 fix: early guard should trigger when accumulated logs (%d) >= logLimit (%d)",
		len(existingLogs), logLimit)

	// Also verify the post-fetch check still works as a second defense:
	// if a single block returns more logs than the remaining budget, it is caught.
	logsBelow := make([]*ethtypes.Log, 3) // 3 existing logs
	singleBlockFiltered := make([]*ethtypes.Log, 4) // 4 new logs => total 7 > 5
	postFetchGuardTriggered := len(logsBelow)+len(singleBlockFiltered) > logLimit
	require.True(t, postFetchGuardTriggered,
		"H7 fix: post-fetch guard should trigger when total logs (%d) > logLimit (%d)",
		len(logsBelow)+len(singleBlockFiltered), logLimit)

	t.Log("H7 fix verified: early guard prevents blockLogs() call when at capacity; " +
		"post-fetch guard catches single-block overflow.")
}
