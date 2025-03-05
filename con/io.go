package con

import (
	"io"
	"net"
	"sync"
)

func DataExchange(conn1, conn2 net.Conn) (int64, int64, error) {
	if conn1 == nil || conn2 == nil {
		return 0, 0, io.ErrUnexpectedEOF
	}
	tcpConn1, ok1 := conn1.(*net.TCPConn)
	tcpConn2, ok2 := conn2.(*net.TCPConn)
	if !ok1 || !ok2 {
		conn1.Close()
		conn2.Close()
		return 0, 0, io.ErrUnexpectedEOF
	}
	var (
		sum1, sum2 int64
		wg         sync.WaitGroup
		errChan    = make(chan error, 2)
	)
	copyData := func(dst, src *net.TCPConn, sum *int64) {
		defer wg.Done()
		n, err := io.Copy(dst, src)
		*sum = n
		errChan <- err
		if err == nil || err == io.EOF {
			dst.CloseWrite()
		} else {
			dst.Close()
			src.Close()
		}
	}
	wg.Add(2)
	go copyData(tcpConn1, tcpConn2, &sum1)
	go copyData(tcpConn2, tcpConn1, &sum2)
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
