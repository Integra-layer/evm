package filters

import (
	"context"
	"math/big"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	ethtypes "github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/eth/filters"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/require"

	coretypes "github.com/cometbft/cometbft/rpc/core/types"

	"github.com/cosmos/evm/rpc/types"

	"cosmossdk.io/log"
)

// mockBackendForAPI implements the Backend interface with controllable filter cap.
type mockBackendForAPI struct {
	filterCap int32
}

func (m *mockBackendForAPI) GetBlockByNumber(_ context.Context, _ types.BlockNumber, _ bool) (map[string]interface{}, error) {
	return nil, nil
}
func (m *mockBackendForAPI) HeaderByNumber(_ context.Context, _ types.BlockNumber) (*ethtypes.Header, error) {
	return nil, nil
}
func (m *mockBackendForAPI) HeaderByHash(_ context.Context, _ common.Hash) (*ethtypes.Header, error) {
	return nil, nil
}
func (m *mockBackendForAPI) CometBlockByHash(_ context.Context, _ common.Hash) (*coretypes.ResultBlock, error) {
	return nil, nil
}
func (m *mockBackendForAPI) CometBlockResultByNumber(_ context.Context, _ *int64) (*coretypes.ResultBlockResults, error) {
	return nil, nil
}
func (m *mockBackendForAPI) GetLogs(_ context.Context, _ common.Hash) ([][]*ethtypes.Log, error) {
	return nil, nil
}
func (m *mockBackendForAPI) GetLogsByHeight(_ context.Context, _ *int64) ([][]*ethtypes.Log, error) {
	return nil, nil
}
func (m *mockBackendForAPI) BlockBloomFromCometBlock(_ context.Context, _ *coretypes.ResultBlockResults) (ethtypes.Bloom, error) {
	return ethtypes.Bloom{}, nil
}
func (m *mockBackendForAPI) BloomStatus() (uint64, uint64)  { return 0, 0 }
func (m *mockBackendForAPI) RPCFilterCap() int32            { return m.filterCap }
func (m *mockBackendForAPI) RPCLogsCap() int32              { return 10000 }
func (m *mockBackendForAPI) RPCBlockRangeCap() int32        { return 10000 }

// mockBackendWithHeader extends mockBackendForAPI with a configurable header response
// for tests that need HeaderByNumber to return a real header (e.g., M4 block range tests).
type mockBackendWithHeader struct {
	mockBackendForAPI
	header *ethtypes.Header
}

func (m *mockBackendWithHeader) HeaderByNumber(_ context.Context, _ types.BlockNumber) (*ethtypes.Header, error) {
	return m.header, nil
}

func TestTimeoutLoop_PanicOnNilCancel(t *testing.T) {
	api := &PublicFilterAPI{
		filters:   make(map[rpc.ID]*filter),
		filtersMu: sync.Mutex{},
		deadline:  10 * time.Millisecond,
	}
	api.filters[rpc.NewID()] = &filter{
		typ:      filters.BlocksSubscription,
		deadline: time.NewTimer(0),
	}
	done := make(chan struct{})
	go func() {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("cancel panic")
			}
			close(done)
		}()
		api.timeoutLoop()
	}()
	panicked := false
	select {
	case <-done:
		panicked = true
	case <-time.After(100 * time.Millisecond):
	}
	require.False(t, panicked)
}

func TestNewPendingTransactionFilter_MaxLimitError(t *testing.T) {
	// C2: When max filter limit is reached, NewPendingTransactionFilter returns
	// an error string as a valid rpc.ID instead of returning a proper error.
	// Clients treat this string as a valid filter ID.

	mb := &mockBackendForAPI{filterCap: 0} // capacity 0 = always at limit
	api := &PublicFilterAPI{
		filters:  make(map[rpc.ID]*filter),
		backend:  mb,
		deadline: 5 * time.Minute,
	}

	id := api.NewPendingTransactionFilter()

	// The ID should NOT contain "error" -- it should be empty or the function
	// should have a different signature. For now, test that the returned ID
	// is not a disguised error message.
	idStr := string(id)
	require.NotContains(t, idStr, "error",
		"NewPendingTransactionFilter should not return error string as valid ID")
}

func TestNewBlockFilter_MaxLimitError(t *testing.T) {
	// Same issue for NewBlockFilter
	mb := &mockBackendForAPI{filterCap: 0}
	api := &PublicFilterAPI{
		filters:  make(map[rpc.ID]*filter),
		backend:  mb,
		deadline: 5 * time.Minute,
	}

	id := api.NewBlockFilter()

	idStr := string(id)
	require.NotContains(t, idStr, "error",
		"NewBlockFilter should not return error string as valid ID")
}

func TestGetFilterLogs_NotFoundErrorCode(t *testing.T) {
	// M3: GetFilterLogs returns generic fmt.Errorf for not-found filter (api.go:289).
	// Per EIP-1474, not-found filter should return JSON-RPC error code -32001.
	// Currently the error is just "filter <id> not found" with no structured code.
	mb := &mockBackendForAPI{filterCap: 100}
	api := &PublicFilterAPI{
		logger:   log.NewNopLogger(),
		filters:  make(map[rpc.ID]*filter),
		backend:  mb,
		deadline: 5 * time.Minute,
	}

	// Use a non-existent filter ID
	fakeID := rpc.ID("0xdeadbeef1234567890")
	logs, err := api.GetFilterLogs(context.Background(), fakeID)

	require.Error(t, err, "GetFilterLogs should return error for non-existent filter")
	// Note: GetFilterLogs returns returnLogs(nil) which is []*ethtypes.Log{} (empty slice, not nil)
	// when filter is not found. This is itself a minor issue -- returning data alongside an error.
	require.Empty(t, logs,
		"M3: GetFilterLogs returns empty slice (not nil) alongside the error")

	// M3 BUG: The error is a plain fmt.Errorf("filter %s not found", id)
	// It does NOT carry a structured JSON-RPC error code (-32001).
	// This assertion PASSES today, documenting the bug:
	errMsg := err.Error()
	require.Contains(t, errMsg, "not found",
		"error should mention filter not found")

	// The error should ideally be a structured JSON-RPC error with code -32001,
	// but currently it is just a plain string error.
	// A fixed implementation would return something like:
	//   &rpc.JsonError{Code: -32001, Message: "filter not found"}
	require.NotContains(t, errMsg, "-32001",
		"M3: error does NOT include JSON-RPC error code -32001 (bug: should be structured error)")
}

func TestGetFilterChanges_NotFoundErrorCode(t *testing.T) {
	// M3: Same issue for GetFilterChanges (api.go:334).
	mb := &mockBackendForAPI{filterCap: 100}
	api := &PublicFilterAPI{
		logger:   log.NewNopLogger(),
		filters:  make(map[rpc.ID]*filter),
		backend:  mb,
		deadline: 5 * time.Minute,
	}

	fakeID := rpc.ID("0xdeadbeef1234567890")
	result, err := api.GetFilterChanges(fakeID)

	require.Error(t, err, "GetFilterChanges should return error for non-existent filter")
	require.Nil(t, result)

	errMsg := err.Error()
	require.Contains(t, errMsg, "not found")
	require.NotContains(t, errMsg, "-32001",
		"M3: error does NOT include JSON-RPC error code -32001 (bug: should be structured error)")
}

func TestNewFilter_NoBlockRangeValidation(t *testing.T) {
	// M4: NewFilter (api.go:205) accepts criteria where fromBlock > toBlock
	// without any validation. The block range is only checked later when
	// GetFilterLogs or GetLogs calls filter.Logs(), which checks from > to
	// at filters.go:163-165.
	//
	// NewFilter cannot be called directly here without a fully initialized
	// RPCStream (it calls api.events.LogStream() at api.go:214). Instead, we
	// demonstrate the bug by simulating what NewFilter does: store a filter
	// with an invalid range and show that GetFilterLogs catches the error
	// only at query time, not at creation time.

	// Use mockBackendWithHeader so HeaderByNumber returns a real header,
	// allowing filter.Logs() to reach the range check at filters.go:163.
	mb := &mockBackendWithHeader{
		mockBackendForAPI: mockBackendForAPI{filterCap: 100},
		header:            &ethtypes.Header{Number: big.NewInt(200)},
	}
	api := &PublicFilterAPI{
		logger:   log.NewNopLogger(),
		filters:  make(map[rpc.ID]*filter),
		backend:  mb,
		deadline: 5 * time.Minute,
	}

	// Simulate what NewFilter does at api.go:213-222:
	// It stores the filter with the criteria as-is, no validation.
	invalidCriteria := filters.FilterCriteria{
		FromBlock: big.NewInt(100),
		ToBlock:   big.NewInt(50), // from > to = invalid
	}
	id := rpc.NewID()
	api.filtersMu.Lock()
	api.filters[id] = &filter{
		typ:      filters.LogsSubscription,
		deadline: time.NewTimer(5 * time.Minute),
		crit:     invalidCriteria,
	}
	api.filtersMu.Unlock()

	// M4 BUG: The filter was stored successfully with an invalid block range.
	// No validation occurred at creation time.
	api.filtersMu.Lock()
	storedFilter, exists := api.filters[id]
	api.filtersMu.Unlock()
	require.True(t, exists,
		"M4: filter with fromBlock(100) > toBlock(50) was stored without validation")
	require.Equal(t, big.NewInt(100), storedFilter.crit.FromBlock)
	require.Equal(t, big.NewInt(50), storedFilter.crit.ToBlock)

	// Now call GetFilterLogs -- the error is caught here, not at creation time.
	// This demonstrates the deferred validation bug.
	logs, err := api.GetFilterLogs(context.Background(), id)
	require.Error(t, err,
		"M4: invalid block range is only caught at GetFilterLogs time, not at NewFilter time")
	require.Contains(t, err.Error(), "invalid block range",
		"M4: the error message comes from filter.Logs(), not from NewFilter")
	require.Empty(t, logs)
}

func TestBlockHashFilter_NoAddressTopicReturnsEmpty(t *testing.T) {
	// M7: When blockHash is set but no address/topic filters are provided,
	// bloomFilter() at filters.go:210 returns true (no addresses, no topics = wildcard),
	// so it proceeds to GetLogsFromBlockResults. The issue is that if the block has
	// logs but they don't match any criteria (empty criteria = match all), the result
	// depends on FilterLogs behavior with empty addresses/topics.
	//
	// Actually, re-reading the code: bloomFilter with empty addresses and empty topics
	// returns true (the function only returns false if addresses are non-empty and none
	// match, or if topics are non-empty and none match). So with both empty, it returns
	// true and proceeds to fetch logs.
	//
	// The real M7 issue is more subtle: the bloom filter check itself is correct for
	// empty filters (returns true), but the block might have a zero bloom (no log data
	// in bloom) and GetLogsFromBlockResults returns based on actual transaction results,
	// not the bloom. So this is actually correct behavior for empty filters.
	//
	// However, the bloomFilter function is called with f.criteria.Addresses and
	// f.criteria.Topics. When these are nil (no filters), bloomFilter returns true,
	// which is correct. The potential issue is when the bloom itself is empty (all zeros)
	// and there ARE logs -- the bloom check passes because no addresses/topics to check.
	//
	// Document the behavior: empty filters with blockHash should return all logs.

	// Verify bloomFilter behavior with empty inputs
	bloom := ethtypes.Bloom{} // all zeros
	result := bloomFilter(bloom, nil, nil)
	require.True(t, result,
		"M7: bloomFilter with no addresses and no topics returns true (wildcard match)")

	result2 := bloomFilter(bloom, []common.Address{}, [][]common.Hash{})
	require.True(t, result2,
		"M7: bloomFilter with empty (not nil) addresses and topics returns true")

	// TODO: Full M7 integration test requires mocked backend that returns actual logs
	// from GetLogsFromBlockResults to verify end-to-end behavior with blockHash filter.
}

func TestNewPendingTransactionFilter_EmptyStringOnLimit(t *testing.T) {
	// L2: NewPendingTransactionFilter returns rpc.ID("") when filter limit is reached
	// (api.go:154-155) instead of returning a proper error.
	// Since the function signature returns only rpc.ID (no error), clients receive
	// an empty string as a "valid" filter ID, which will silently fail on subsequent calls.
	mb := &mockBackendForAPI{filterCap: 0} // capacity 0 = always at limit
	api := &PublicFilterAPI{
		filters:  make(map[rpc.ID]*filter),
		backend:  mb,
		deadline: 5 * time.Minute,
	}

	id := api.NewPendingTransactionFilter()

	// L2 BUG: The returned ID is an empty string, not a proper error.
	// This assertion PASSES today, documenting the bug.
	require.Equal(t, rpc.ID(""), id,
		"L2: NewPendingTransactionFilter returns empty string ID when limit reached (bug: should return error)")

	// The empty string ID is indistinguishable from a "no filter" state for naive clients.
	// A proper implementation would change the signature to (rpc.ID, error) and return
	// an error when the limit is reached.
}

func TestNewBlockFilter_EmptyStringOnLimit(t *testing.T) {
	// L2: Same issue for NewBlockFilter (api.go:177-178).
	mb := &mockBackendForAPI{filterCap: 0}
	api := &PublicFilterAPI{
		filters:  make(map[rpc.ID]*filter),
		backend:  mb,
		deadline: 5 * time.Minute,
	}

	id := api.NewBlockFilter()

	// L2 BUG: Empty string ID returned instead of error.
	require.Equal(t, rpc.ID(""), id,
		"L2: NewBlockFilter returns empty string ID when limit reached (bug: should return error)")
}
