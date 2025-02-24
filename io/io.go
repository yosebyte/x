package internal

import (
	"context"
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
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	copyData := func(dst, src net.Conn, sum *int64) {
		defer wg.Done()
		pr, pw := io.Pipe()
		go func() {
			_, err := io.Copy(pw, src)
			pw.CloseWithError(err)
		}()
		go func() {
			<-ctx.Done()
			pr.CloseWithError(context.Canceled)
		}()
		n, err := io.Copy(dst, pr)
		*sum = n
		errChan <- err
		cancel()
	}
	wg.Add(2)
	go copyData(conn1, conn2, &sum1)
	go copyData(conn2, conn1, &sum2)
	wg.Wait()
	close(errChan)
	for err := range errChan {
		if err != nil {
			return sum1, sum2, err
		}
	}
	return sum1, sum2, io.EOF
}
