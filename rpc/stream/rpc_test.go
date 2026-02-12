package stream

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/require"

	coretypes "github.com/cometbft/cometbft/rpc/core/types"

	"cosmossdk.io/log"
)

// failingEventsClient is a mock rpcclient.EventsClient whose Subscribe always
// returns an error. This lets us exercise the panic paths in initSubscriptions
// without needing a live CometBFT node.
type failingEventsClient struct {
	subscribeErr     error
	unsubscribeAllOK bool // track whether UnsubscribeAll was called
}

func (f *failingEventsClient) Subscribe(_ context.Context, _, _ string, _ ...int) (<-chan coretypes.ResultEvent, error) {
	return nil, f.subscribeErr
}

func (f *failingEventsClient) Unsubscribe(_ context.Context, _, _ string) error {
	return nil
}

func (f *failingEventsClient) UnsubscribeAll(_ context.Context, _ string) error {
	f.unsubscribeAllOK = true
	return nil
}

// firstCallFailEventsClient fails on the SECOND Subscribe call (for the
// evmEvents subscription) while succeeding on the first (blockEvents).
// This exercises the second panic path at rpc.go:99.
type firstCallFailEventsClient struct {
	callCount int
	secondErr error
}

func (f *firstCallFailEventsClient) Subscribe(_ context.Context, _, _ string, _ ...int) (<-chan coretypes.ResultEvent, error) {
	f.callCount++
	if f.callCount == 1 {
		// First subscription (blockEvents) succeeds
		ch := make(chan coretypes.ResultEvent, 1)
		return ch, nil
	}
	// Second subscription (evmEvents) fails
	return nil, f.secondErr
}

func (f *firstCallFailEventsClient) Unsubscribe(_ context.Context, _, _ string) error {
	return nil
}

func (f *firstCallFailEventsClient) UnsubscribeAll(_ context.Context, _ string) error {
	return nil
}

// ---------------------------------------------------------------------------
// C2: Stream init panics -- RED phase
//
// initSubscriptions() at rpc.go:91 and rpc.go:99 calls panic(err) when event
// subscriptions fail. This is a critical bug: a transient CometBFT error
// crashes the entire node instead of returning a recoverable error.
//
// These tests verify that initSubscriptions handles subscribe failures
// gracefully by logging errors and returning, instead of panicking.
// The streams are allocated before the subscribe calls, so callers get
// non-nil but empty streams — graceful degradation.
// ---------------------------------------------------------------------------

func TestHeaderStream_GracefulOnFirstSubscribeFailure(t *testing.T) {
	// C2: rpc.go:91 — first Subscribe (blockEvents) fails -> panic
	evtClient := &failingEventsClient{
		subscribeErr: errors.New("connection refused"),
	}
	rpcStream := NewRPCStreams(evtClient, log.NewNopLogger(), nil)

	// GREEN: initSubscriptions logs the error and returns gracefully.
	// Streams are allocated before subscribe, so they are non-nil but empty.
	require.NotPanics(t, func() {
		stream := rpcStream.HeaderStream()
		require.NotNil(t, stream, "C2: HeaderStream() should return non-nil stream even on subscribe failure")
	})
}

func TestLogStream_GracefulOnFirstSubscribeFailure(t *testing.T) {
	// C2: rpc.go:91 — LogStream also calls initSubscriptions, same panic path
	evtClient := &failingEventsClient{
		subscribeErr: errors.New("connection refused"),
	}
	rpcStream := NewRPCStreams(evtClient, log.NewNopLogger(), nil)

	require.NotPanics(t, func() {
		stream := rpcStream.LogStream()
		require.NotNil(t, stream, "C2: LogStream() should return non-nil stream even on subscribe failure")
	})
}

func TestHeaderStream_GracefulOnSecondSubscribeFailure(t *testing.T) {
	// C2: rpc.go:99 — first Subscribe (blockEvents) succeeds, second
	// Subscribe (evmEvents) fails -> panic after attempting UnsubscribeAll
	evtClient := &firstCallFailEventsClient{
		secondErr: errors.New("evmEvents subscription failed"),
	}
	rpcStream := NewRPCStreams(evtClient, log.NewNopLogger(), nil)

	require.NotPanics(t, func() {
		stream := rpcStream.HeaderStream()
		require.NotNil(t, stream, "C2: HeaderStream() should return non-nil stream even on second subscribe failure")
	})
}

func TestLogStream_GracefulOnSecondSubscribeFailure(t *testing.T) {
	// C2: rpc.go:99 — same second-subscribe panic path via LogStream
	evtClient := &firstCallFailEventsClient{
		secondErr: errors.New("evmEvents subscription failed"),
	}
	rpcStream := NewRPCStreams(evtClient, log.NewNopLogger(), nil)

	require.NotPanics(t, func() {
		stream := rpcStream.LogStream()
		require.NotNil(t, stream, "C2: LogStream() should return non-nil stream even on second subscribe failure")
	})
}
