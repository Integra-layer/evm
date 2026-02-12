package utils

import (
	"math"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestSafeInt32ToUint(t *testing.T) {
	tests := []struct {
		name    string
		input   int32
		want    uint
		wantErr bool
	}{
		{"positive", 42, 42, false},
		{"zero", 0, 0, false},
		{"max_int32", math.MaxInt32, uint(math.MaxInt32), false},
		{"negative_one", -1, 0, true},
		{"min_int32", math.MinInt32, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := SafeInt32ToUint(tt.input)
			if tt.wantErr {
				require.Error(t, err)
				require.Equal(t, uint(0), got)
			} else {
				require.NoError(t, err)
				require.Equal(t, tt.want, got)
			}
		})
	}
}

func TestSafeUint64(t *testing.T) {
	tests := []struct {
		name    string
		input   int64
		want    uint64
		wantErr bool
	}{
		{"positive", 42, 42, false},
		{"zero", 0, 0, false},
		{"max_int64", math.MaxInt64, uint64(math.MaxInt64), false},
		{"negative_one", -1, 0, true},
		{"min_int64", math.MinInt64, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := SafeUint64(tt.input)
			if tt.wantErr {
				require.Error(t, err)
				require.Equal(t, uint64(0), got)
			} else {
				require.NoError(t, err)
				require.Equal(t, tt.want, got)
			}
		})
	}
}

func TestSafeInt64(t *testing.T) {
	tests := []struct {
		name    string
		input   uint64
		want    int64
		wantErr bool
	}{
		{"positive", 42, 42, false},
		{"zero", 0, 0, false},
		{"max_int64", uint64(math.MaxInt64), math.MaxInt64, false},
		{"overflow", uint64(math.MaxInt64) + 1, 0, true},
		{"max_uint64", math.MaxUint64, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := SafeInt64(tt.input)
			if tt.wantErr {
				require.Error(t, err)
				require.Equal(t, int64(0), got)
			} else {
				require.NoError(t, err)
				require.Equal(t, tt.want, got)
			}
		})
	}
}
