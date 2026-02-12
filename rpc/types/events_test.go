package types

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"

	abci "github.com/cometbft/cometbft/abci/types"

	evmtypes "github.com/cosmos/evm/x/vm/types"
)

func TestParseTxResult(t *testing.T) {
	address := "0x57f96e6B86CdeFdB3d412547816a82E3E0EbF9D2"
	txHash := common.BigToHash(big.NewInt(1))
	txHash2 := common.BigToHash(big.NewInt(2))

	testCases := []struct {
		name     string
		response abci.ExecTxResult
		expTxs   []*ParsedTx // expected parse result, nil means expect error.
	}{
		{
			"format 1 events",
			abci.ExecTxResult{
				GasUsed: 21000,
				Events: []abci.Event{
					{Type: "coin_received", Attributes: []abci.EventAttribute{
						{Key: "receiver", Value: "ethm12luku6uxehhak02py4rcz65zu0swh7wjun6msa"},
						{Key: "amount", Value: "1252860basetcro"},
					}},
					{Type: "coin_spent", Attributes: []abci.EventAttribute{
						{Key: "spender", Value: "ethm17xpfvakm2amg962yls6f84z3kell8c5lthdzgl"},
						{Key: "amount", Value: "1252860basetcro"},
					}},
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "ethereumTxHash", Value: txHash.Hex()},
						{Key: "txIndex", Value: "10"},
						{Key: "amount", Value: "1000"},
						{Key: "txGasUsed", Value: "21000"},
						{Key: "txHash", Value: "14A84ED06282645EFBF080E0B7ED80D8D8D6A36337668A12B5F229F81CDD3F57"},
						{Key: "recipient", Value: "0x775b87ef5D82ca211811C1a02CE0fE0CA3a455d7"},
					}},
					{Type: "message", Attributes: []abci.EventAttribute{
						{Key: "action", Value: "/ehermint.evm.v1.MsgEthereumTx"},
						{Key: "key", Value: "ethm17xpfvakm2amg962yls6f84z3kell8c5lthdzgl"},
						{Key: "module", Value: "evm"},
						{Key: "sender", Value: address},
					}},
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "ethereumTxHash", Value: txHash2.Hex()},
						{Key: "txIndex", Value: "11"},
						{Key: "amount", Value: "1000"},
						{Key: "txGasUsed", Value: "21000"},
						{Key: "txHash", Value: "14A84ED06282645EFBF080E0B7ED80D8D8D6A36337668A12B5F229F81CDD3F57"},
						{Key: "recipient", Value: "0x775b87ef5D82ca211811C1a02CE0fE0CA3a455d7"},
						{Key: "ethereumTxFailed", Value: "contract everted"},
					}},
				},
			},
			[]*ParsedTx{
				{
					MsgIndex:   0,
					Hash:       txHash,
					EthTxIndex: 10,
					GasUsed:    21000,
					Failed:     false,
				},
				{
					MsgIndex:   1,
					Hash:       txHash2,
					EthTxIndex: 11,
					GasUsed:    21000,
					Failed:     true,
				},
			},
		},
		{
			"format 2 events",
			abci.ExecTxResult{
				GasUsed: 21000,
				Events: []abci.Event{
					{Type: "coin_received", Attributes: []abci.EventAttribute{
						{Key: "receiver", Value: "ethm12luku6uxehhak02py4rcz65zu0swh7wjun6msa"},
						{Key: "amount", Value: "1252860basetcro"},
					}},
					{Type: "coin_spent", Attributes: []abci.EventAttribute{
						{Key: "spender", Value: "ethm17xpfvakm2amg962yls6f84z3kell8c5lthdzgl"},
						{Key: "amount", Value: "1252860basetcro"},
					}},
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "ethereumTxHash", Value: txHash.Hex()},
						{Key: "txIndex", Value: "0"},
					}},
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "amount", Value: "1000"},
						{Key: "ethereumTxHash", Value: txHash.Hex()},
						{Key: "txIndex", Value: "0"},
						{Key: "txGasUsed", Value: "21000"},
						{Key: "txHash", Value: "14A84ED06282645EFBF080E0B7ED80D8D8D6A36337668A12B5F229F81CDD3F57"},
						{Key: "recipient", Value: "0x775b87ef5D82ca211811C1a02CE0fE0CA3a455d7"},
					}},
					{Type: "message", Attributes: []abci.EventAttribute{
						{Key: "action", Value: "/ehermint.evm.v1.MsgEthereumTx"},
						{Key: "key", Value: "ethm17xpfvakm2amg962yls6f84z3kell8c5lthdzgl"},
						{Key: "module", Value: "evm"},
						{Key: "sender", Value: address},
					}},
				},
			},
			[]*ParsedTx{
				{
					MsgIndex:   0,
					Hash:       txHash,
					EthTxIndex: 0,
					GasUsed:    21000,
					Failed:     false,
				},
			},
		},
		{
			"format 1 events, failed",
			abci.ExecTxResult{
				GasUsed: 21000,
				Events: []abci.Event{
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "ethereumTxHash", Value: txHash.Hex()},
						{Key: "txIndex", Value: "10"},
						{Key: "amount", Value: "1000"},
						{Key: "txGasUsed", Value: "21000"},
						{Key: "txHash", Value: "14A84ED06282645EFBF080E0B7ED80D8D8D6A36337668A12B5F229F81CDD3F57"},
						{Key: "recipient", Value: "0x775b87ef5D82ca211811C1a02CE0fE0CA3a455d7"},
					}},
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "ethereumTxHash", Value: txHash2.Hex()},
						{Key: "txIndex", Value: "10"},
						{Key: "amount", Value: "1000"},
						{Key: "txGasUsed", Value: "0x01"},
						{Key: "txHash", Value: "14A84ED06282645EFBF080E0B7ED80D8D8D6A36337668A12B5F229F81CDD3F57"},
						{Key: "recipient", Value: "0x775b87ef5D82ca211811C1a02CE0fE0CA3a455d7"},
						{Key: "ethereumTxFailed", Value: "contract everted"},
					}},
				},
			},
			nil,
		},
		{
			"format 2 events failed",
			abci.ExecTxResult{
				GasUsed: 21000,
				Events: []abci.Event{
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "ethereumTxHash", Value: txHash.Hex()},
						{Key: "txIndex", Value: "10"},
					}},
					{Type: evmtypes.EventTypeEthereumTx, Attributes: []abci.EventAttribute{
						{Key: "amount", Value: "1000"},
						{Key: "txGasUsed", Value: "0x01"},
						{Key: "txHash", Value: "14A84ED06282645EFBF080E0B7ED80D8D8D6A36337668A12B5F229F81CDD3F57"},
						{Key: "recipient", Value: "0x775b87ef5D82ca211811C1a02CE0fE0CA3a455d7"},
					}},
				},
			},
			nil,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			parsed, err := ParseTxResult(&tc.response, nil) //#nosec G601 -- fine for tests
			if tc.expTxs == nil {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
				for msgIndex, expTx := range tc.expTxs {
					require.Equal(t, expTx, parsed.GetTxByMsgIndex(msgIndex))
					require.Equal(t, expTx, parsed.GetTxByHash(expTx.Hash))
					require.Equal(t, expTx, parsed.GetTxByTxIndex(int(expTx.EthTxIndex)))
				}
				// non-exists tx hash
				require.Nil(t, parsed.GetTxByHash(common.Hash{}))
				// out of range
				require.Nil(t, parsed.GetTxByMsgIndex(len(tc.expTxs)))
				require.Nil(t, parsed.GetTxByTxIndex(99999999))
			}
		})
	}
}

func TestParseTxResult_NegativeGasUsed(t *testing.T) {
	// The check at events.go:125-127 rejects negative GasUsed before the
	// len(p.Txs)==1 fallback, even when there are 0 parsed txs.
	result := &abci.ExecTxResult{
		Code:    0,
		GasUsed: -1,
		Events:  []abci.Event{},
	}
	_, err := ParseTxResult(result, nil)
	require.Error(t, err, "ParseTxResult should reject negative GasUsed")
	require.Contains(t, err.Error(), "negative gas used",
		"error message should mention negative gas used")
}

func TestFillTxAttribute_ParseUintBitSize31RejectsValidUint32(t *testing.T) {
	// H5: RED — ParseUint bitSize=31 rejects valid uint32 values >= 2^31.
	// At events.go:242, strconv.ParseUint(value, 10, 31) limits txIndex to
	// 0..2^31-1 (2147483647). Values in range [2^31, 2^32-1] are valid uint32
	// values but are rejected because bitSize=31 instead of 32.
	// The int32 cast at line 246 would then also be incorrect for values >= 2^31,
	// but the ParseUint rejects them first.

	testCases := []struct {
		name        string
		value       string
		expectErr   bool
		errContains string
		expectIndex int32
	}{
		{
			name:        "max int32 (2^31 - 1) accepted",
			value:       "2147483647",
			expectErr:   false,
			expectIndex: 2147483647,
		},
		{
			name:        "2^31 exceeds max int32",
			value:       "2147483648",
			expectErr:   true,
			errContains: "exceeds max int32",
		},
		{
			name:        "max uint32 (2^32 - 1) exceeds max int32",
			value:       "4294967295",
			expectErr:   true,
			errContains: "exceeds max int32",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tx := NewParsedTx(0)
			err := fillTxAttribute(&tx, evmtypes.AttributeKeyTxIndex, tc.value)
			if tc.expectErr {
				require.Error(t, err,
					"H5: value %s should be rejected by explicit bounds check", tc.value)
				require.Contains(t, err.Error(), tc.errContains)
			} else {
				require.NoError(t, err)
				require.Equal(t, tc.expectIndex, tx.EthTxIndex)
			}
		})
	}
}
