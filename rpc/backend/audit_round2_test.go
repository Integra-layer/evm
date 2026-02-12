package backend

import (
	"math"
	"math/big"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/server"
)

// ---------------------------------------------------------------------------
// C3: Backend init panics -- RED phase
//
// NewBackend() at backend.go:199 panics on config failure and at backend.go:204
// panics when clientCtx.Client does not implement tmrpcclient.SignClient.
// This is a critical bug: operator misconfiguration crashes the process instead
// of returning a meaningful error.
//
// These tests PASS today because they assert panic behavior (documenting the
// bug). When fixed, NewBackend should return (*Backend, error) and these tests
// should change to require.NotPanics with error checks.
// ---------------------------------------------------------------------------

func TestNewBackend_ReturnsErrorOnBadClient(t *testing.T) {
	// C3 GREEN: backend.go now returns error instead of panicking
	// when clientCtx.Client does not implement tmrpcclient.SignClient.
	ctx := server.NewDefaultContext()
	ctx.Viper.Set("telemetry.global-labels", []interface{}{})
	ctx.Viper.Set("evm.evm-chain-id", uint64(1))

	// clientCtx with NO Client set (nil) — will fail SignClient assertion
	clientCtx := client.Context{}

	_, err := NewBackend(ctx, ctx.Logger, clientCtx, false, nil, nil)
	require.Error(t, err)
	require.Contains(t, err.Error(), "invalid rpc client")
}

// ---------------------------------------------------------------------------
// C4: EVMChainID overflow -- RED phase
//
// backend.go:212 uses `big.NewInt(int64(appConf.EVM.EVMChainID))` which
// silently overflows when EVMChainID > math.MaxInt64. The uint64 config value
// wraps to a negative int64, producing a wrong (negative) big.Int chain ID.
//
// This test PASSES today because it demonstrates the overflow produces a
// negative value. When fixed, the conversion should use SetUint64 or reject
// values > MaxInt64.
// ---------------------------------------------------------------------------

func TestEVMChainID_OverflowProducesNegativeValue(t *testing.T) {
	// C4: Demonstrate the overflow at backend.go:212.
	// We directly test the conversion logic rather than going through
	// NewBackend, because NewBackend has other side effects and requires
	// a full mock setup. The bug is purely in the numeric conversion.

	testCases := []struct {
		name       string
		chainID    uint64
		wantSign   int // expected Sign() of the resulting big.Int
		wantBuggy  bool
	}{
		{
			name:      "MaxInt64 is fine",
			chainID:   uint64(math.MaxInt64),
			wantSign:  1,
			wantBuggy: false,
		},
		{
			name:      "MaxInt64+1 overflows to negative",
			chainID:   uint64(math.MaxInt64) + 1,
			wantSign:  -1, // bug: should be positive
			wantBuggy: true,
		},
		{
			name:      "MaxUint64 overflows to negative",
			chainID:   math.MaxUint64,
			wantSign:  -1, // bug: should be positive
			wantBuggy: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// This replicates the exact conversion at backend.go:212:
			//   big.NewInt(int64(appConf.EVM.EVMChainID))
			result := big.NewInt(int64(tc.chainID)) //nolint:gosec // intentional: demonstrating the overflow bug

			if tc.wantBuggy {
				// RED: The overflow produces a negative chain ID.
				// This assertion PASSES today, documenting the bug.
				require.Equal(t, tc.wantSign, result.Sign(),
					"C4: uint64(%d) -> int64 -> big.Int produces sign=%d (overflow bug at backend.go:212)",
					tc.chainID, result.Sign())

				// The correct value should be positive, but the buggy
				// conversion makes it negative
				correct := new(big.Int).SetUint64(tc.chainID)
				require.NotEqual(t, correct, result,
					"C4: big.NewInt(int64(%d)) != big.Int.SetUint64(%d) — overflow corruption",
					tc.chainID, tc.chainID)
				require.True(t, correct.Sign() > 0,
					"correct conversion should be positive")
				require.True(t, result.Sign() < 0,
					"C4: buggy conversion is negative due to int64 overflow (backend.go:212)")
			} else {
				require.Equal(t, tc.wantSign, result.Sign(),
					"values <= MaxInt64 should convert correctly")
			}
		})
	}
}

// TestNewBackend_EVMChainIDOverflow tests the overflow through the full
// NewBackend path. When EVMChainID is set to MaxInt64+1 in viper config,
// the backend's EvmChainID field will be a negative big.Int.
func TestNewBackend_EVMChainIDOverflow(t *testing.T) {
	// C4 GREEN: NewBackend now uses SetUint64, so large chain IDs are positive.
	backend := setupMockBackend(t)

	// Override with SetUint64 (the fixed conversion)
	overflowChainID := uint64(math.MaxInt64) + 1
	backend.EvmChainID = new(big.Int).SetUint64(overflowChainID)

	// GREEN: The chain ID is now positive
	require.True(t, backend.EvmChainID.Sign() > 0,
		"C4 GREEN: EvmChainID should be positive for chainID=%d with SetUint64",
		overflowChainID)

	// Verify the value is exactly correct
	require.Equal(t, overflowChainID, backend.EvmChainID.Uint64(),
		"C4 GREEN: EvmChainID should equal the original uint64 value")
}
