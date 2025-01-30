package io

import (
	"io"
	"net"
	"sync"
)

func DataExchange(conn1, conn2 net.Conn) error {
	var (
		once1, once2 sync.Once
		wg           sync.WaitGroup
	)
	closeConn := func(conn net.Conn, once *sync.Once) {
		once.Do(func() {
			if conn != nil {
				conn.Close()
			}
		})
	}
	errChan := make(chan error, 2)
	wg.Add(2)
	exchange := func(dst, src net.Conn, closeDst, closeSrc *sync.Once) {
		defer func() {
			closeConn(dst, closeDst)
			closeConn(src, closeSrc)
			wg.Done()
		}()
		_, err := io.Copy(dst, src)
		errChan <- err
	}
	go exchange(conn1, conn2, &once1, &once2)
	go exchange(conn2, conn1, &once2, &once1)
	wg.Wait()
	close(errChan)
	for err := range errChan {
		if err != nil {
			return err
		}
	}
	return io.EOF
}
