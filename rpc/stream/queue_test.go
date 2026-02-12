/*
The MIT License (MIT)

Copyright (c) 2014 Evan Huus

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

package stream

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestQueueSimple(t *testing.T) {
	q := New[int]()

	for i := 0; i < minQueueLen; i++ {
		q.Add(i)
	}
	for i := 0; i < minQueueLen; i++ {
		if q.Peek() != i {
			t.Error("peek", i, "had value", q.Peek())
		}
		x := q.Remove()
		if x != i {
			t.Error("remove", i, "had value", x)
		}
	}
}

func TestQueueWrapping(t *testing.T) {
	q := New[int]()

	for i := 0; i < minQueueLen; i++ {
		q.Add(i)
	}
	for i := 0; i < 3; i++ {
		q.Remove()
		q.Add(minQueueLen + i)
	}

	for i := 0; i < minQueueLen; i++ {
		if q.Peek() != i+3 {
			t.Error("peek", i, "had value", q.Peek())
		}
		q.Remove()
	}
}

func TestQueueLength(t *testing.T) {
	q := New[int]()

	if q.Length() != 0 {
		t.Error("empty queue length not 0")
	}

	for i := 0; i < 1000; i++ {
		q.Add(i)
		if q.Length() != i+1 {
			t.Error("adding: queue with", i, "elements has length", q.Length())
		}
	}
	for i := 0; i < 1000; i++ {
		q.Remove()
		if q.Length() != 1000-i-1 {
			t.Error("removing: queue with", 1000-i-i, "elements has length", q.Length())
		}
	}
}

func TestQueueGet(t *testing.T) {
	q := New[int]()

	for i := 0; i < 1000; i++ {
		q.Add(i)
		for j := 0; j < q.Length(); j++ {
			if q.Get(j) != j {
				t.Errorf("index %d doesn't contain %d", j, j)
			}
		}
	}
}

func TestQueueGetNegative(t *testing.T) {
	q := New[int]()

	for i := 0; i < 1000; i++ {
		q.Add(i)
		for j := 1; j <= q.Length(); j++ {
			if q.Get(-j) != q.Length()-j {
				t.Errorf("index %d doesn't contain %d", -j, q.Length()-j)
			}
		}
	}
}

func TestQueueGetOutOfRangePanics(t *testing.T) {
	q := New[int]()

	q.Add(1)
	q.Add(2)
	q.Add(3)

	assertPanics(t, "should panic when negative index", func() {
		q.Get(-4)
	})

	assertPanics(t, "should panic when index greater than length", func() {
		q.Get(4)
	})
}

func TestQueuePeekOutOfRangePanics(t *testing.T) {
	q := New[any]()

	assertPanics(t, "should panic when peeking empty queue", func() {
		q.Peek()
	})

	q.Add(1)
	q.Remove()

	assertPanics(t, "should panic when peeking emptied queue", func() {
		q.Peek()
	})
}

func TestQueueRemoveOutOfRangePanics(t *testing.T) {
	q := New[int]()

	assertPanics(t, "should panic when removing empty queue", func() {
		q.Remove()
	})

	q.Add(1)
	q.Remove()

	assertPanics(t, "should panic when removing emptied queue", func() {
		q.Remove()
	})
}

func assertPanics(t *testing.T, name string, f func()) {
	t.Helper()
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("%s: didn't panic as expected", name)
		}
	}()

	f()
}

// ---------------------------------------------------------------------------
// H3: Queue operations panic on empty -- RED phase
//
// Peek (queue.go:96), Remove (queue.go:141), and Get (queue.go:131) panic
// when called on an empty queue instead of returning (value, error). This is
// a hardening issue: callers cannot gracefully handle empty-queue scenarios
// without wrapping every call in a recover().
//
// These tests PASS today because they use require.Panics to document the bug.
// When fixed, the signatures should change to return (V, error) and these
// tests should use require.NotPanics + require.Error instead.
// ---------------------------------------------------------------------------

func TestQueuePeekPanicsInsteadOfError(t *testing.T) {
	// H3: queue.go:96 — Peek on empty queue panics instead of returning error
	q := New[int]()

	require.Panics(t, func() {
		q.Peek()
	}, "H3: Peek() on empty queue panics instead of returning (zero, error) (queue.go:96)")

	// Also test PeekP for completeness — same panic path
	require.Panics(t, func() {
		q.PeekP()
	}, "H3: PeekP() on empty queue panics instead of returning (nil, error) (queue.go:94-98)")
}

func TestQueueRemovePanicsInsteadOfError(t *testing.T) {
	// H3: queue.go:141 — Remove on empty queue panics instead of returning error
	q := New[int]()

	require.Panics(t, func() {
		q.Remove()
	}, "H3: Remove() on empty queue panics instead of returning (zero, error) (queue.go:141)")

	// Also verify that draining a non-empty queue then calling Remove panics
	q.Add(42)
	_ = q.Remove() // drains the queue
	require.Panics(t, func() {
		q.Remove()
	}, "H3: Remove() on drained queue panics instead of returning (zero, error) (queue.go:141)")
}

func TestQueueGetPanicsInsteadOfError(t *testing.T) {
	// H3: queue.go:131 — Get with invalid index panics instead of returning error
	q := New[int]()

	// Get(0) on empty queue
	require.Panics(t, func() {
		q.Get(0)
	}, "H3: Get(0) on empty queue panics instead of returning (zero, error) (queue.go:131)")

	// Get(-1) on empty queue — exercises the negative index + empty path
	require.Panics(t, func() {
		q.Get(-1)
	}, "H3: Get(-1) on empty queue panics instead of returning (zero, error) (queue.go:131)")

	// GetP also panics on invalid index
	require.Panics(t, func() {
		q.GetP(0)
	}, "H3: GetP(0) on empty queue panics instead of returning (nil, error) (queue.go:125-135)")
}

// WARNING: Go's benchmark utility (go test -bench .) increases the number of
// iterations until the benchmarks take a reasonable amount of time to run; memory usage
// is *NOT* considered. On a fast CPU, these benchmarks can fill hundreds of GB of memory
// (and then hang when they start to swap). You can manually control the number of iterations
// with the `-benchtime` argument. Passing `-benchtime 1000000x` seems to be about right.

func BenchmarkQueueSerial(b *testing.B) {
	q := New[any]()
	for i := 0; i < b.N; i++ {
		q.Add(nil)
	}
	for i := 0; i < b.N; i++ {
		q.Peek()
		q.Remove()
	}
}

func BenchmarkQueueGet(b *testing.B) {
	q := New[int]()
	for i := 0; i < b.N; i++ {
		q.Add(i)
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		q.Get(i)
	}
}

func BenchmarkQueueTickTock(b *testing.B) {
	q := New[any]()
	for i := 0; i < b.N; i++ {
		q.Add(nil)
		q.Peek()
		q.Remove()
	}
}
