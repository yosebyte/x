package io

import (
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

func DataExchange(conn1, conn2 net.Conn) (int64, error) {
	if conn1 == nil || conn2 == nil {
		return 0, io.ErrUnexpectedEOF
	}
	var (
		sum  int64
		wg   sync.WaitGroup
		once sync.Once
	)
	errChan := make(chan error, 2)
	stopCopy := func() {
		once.Do(func() {
			conn1.SetReadDeadline(time.Now())
			conn2.SetReadDeadline(time.Now())
		})
	}
	exchange := func(dst, src net.Conn) {
		defer wg.Done()
		n, err := io.Copy(dst, src)
		atomic.AddInt64(&sum, n)
		if err != nil {
			stopCopy()
		}
		errChan <- err
	}
	wg.Add(2)
	go exchange(conn1, conn2)
	go exchange(conn2, conn1)
	wg.Wait()
	close(errChan)
	conn1.SetReadDeadline(time.Time{})
	conn2.SetReadDeadline(time.Time{})
	return sum, <-errChan
}
