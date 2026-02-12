package filters

import (
	"context"
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
