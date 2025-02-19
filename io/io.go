package main

import (
	"context"
	"io"
	"net"
	"sync"
	"sync/atomic"
)

type exchangeData struct {
	conn1   net.Conn
	conn2   net.Conn
	sum     int64
	errChan chan error
}

func DataExchange(conn1, conn2 net.Conn) (int64, error) {
	if conn1 == nil || conn2 == nil {
		return 0, io.ErrUnexpectedEOF
	}
	data := &exchangeData{
		conn1:   conn1,
		conn2:   conn2,
		errChan: make(chan error, 2),
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var wg sync.WaitGroup
	wg.Add(2)
	go exchange(ctx, &wg, data, true)
	go exchange(ctx, &wg, data, false)
	wg.Wait()
	close(data.errChan)
	select {
	case err := <-data.errChan:
		return data.sum, err
	default:
		return data.sum, io.EOF
	}
}

func exchange(ctx context.Context, wg *sync.WaitGroup, data *exchangeData, coin bool) {
	defer wg.Done()
	var src, dst net.Conn
	if coin {
		src, dst = data.conn1, data.conn2
	} else {
		src, dst = data.conn2, data.conn1
	}
	n, err := io.Copy(dst, src)
	atomic.AddInt64(&data.sum, n)
	if err != nil {
		data.errChan <- err
		cancel()
	}
}