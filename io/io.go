package io

import (
	"io"
	"net"
	"sync"
)

func DataExchange(conn1, conn2 net.Conn) (int64, int64, error) {
	if conn1 == nil || conn2 == nil {
		return 0, 0, io.ErrUnexpectedEOF
	}
	var (
		sum1, sum2 int64
		wg         sync.WaitGroup
		errChan    = make(chan error, 2)
	)
	copyData := func(dst, src net.Conn, sum *int64) {
		defer wg.Done()
		n, err := io.Copy(dst, src)
		*sum = n
		errChan <- err
		if err == nil || err == io.EOF {
			if c, ok := dst.(interface{ CloseWrite() error }); ok {
				c.CloseWrite()
			}
		} else {
			src.Close()
		}
	}
	wg.Add(2)
	go copyData(conn1, conn2, &sum1)
	go copyData(conn2, conn1, &sum2)
	wg.Wait()
	close(errChan)
	conn1.Close()
	conn2.Close()
	for err := range errChan {
		if err != nil {
			return sum1, sum2, err
		}
	}
	return sum1, sum2, io.EOF
}
