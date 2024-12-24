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
	closeConn1 := func() {
		once1.Do(func() {
			if conn1 != nil {
				conn1.Close()
			}
		})
	}
	closeConn2 := func() {
		once2.Do(func() {
			if conn2 != nil {
				conn2.Close()
			}
		})
	}
	errChan := make(chan error, 2)
	wg.Add(2)
	go func() {
		defer func() {
			closeConn1()
			closeConn2()
			wg.Done()
		}()
		if _, err := io.Copy(conn1, conn2); err != nil {
			errChan <- err
		}
	}()
	go func() {
		defer func() {
			closeConn2()
			closeConn1()
			wg.Done()
		}()
		if _, err := io.Copy(conn2, conn1); err != nil {
			errChan <- err
		}
	}()
	wg.Wait()
	if err := <-errChan; err == nil {
		return io.EOF
	} else {
		return err
	}
}
