package conn

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net"
	"sync"
	"time"
)

type Pool struct {
	mu       sync.Mutex
	conns    sync.Map
	idChan   chan string
	dialer   func() (net.Conn, error)
	listener net.Listener
	capacity int
	minCap   int
	maxCap   int
	interval time.Duration
	minIvl   time.Duration
	maxIvl   time.Duration
	ctx      context.Context
	cancel   context.CancelFunc
}

func NewBrokerPool(minCap, maxCap int, minIvl, maxIvl time.Duration, dialer func() (net.Conn, error)) *Pool {
	if minCap <= 0 {
		minCap = 1
	}
	if maxCap <= 0 {
		maxCap = 1
	}
	if minCap > maxCap {
		minCap, maxCap = maxCap, minCap
	}
	if minIvl <= 0 {
		minIvl = time.Second
	}
	if maxIvl <= 0 {
		maxIvl = time.Second
	}
	if minIvl > maxIvl {
		minIvl, maxIvl = maxIvl, minIvl
	}
	return &Pool{
		conns:    sync.Map{},
		idChan:   make(chan string, maxCap),
		dialer:   dialer,
		capacity: minCap,
		minCap:   minCap,
		maxCap:   maxCap,
		interval: minIvl,
		minIvl:   minIvl,
		maxIvl:   maxIvl,
	}
}

func NewClientPool(minCap, maxCap int, dialer func() (net.Conn, error)) *Pool {
	if minCap <= 0 {
		minCap = 1
	}
	if maxCap <= 0 {
		maxCap = 1
	}
	if minCap > maxCap {
		minCap, maxCap = maxCap, minCap
	}
	return &Pool{
		conns:    sync.Map{},
		idChan:   make(chan string, maxCap),
		dialer:   dialer,
		capacity: minCap,
		minCap:   minCap,
		maxCap:   maxCap,
		interval: time.Second,
	}
}

func NewServerPool(maxCap int, listener net.Listener) *Pool {
	if maxCap <= 0 {
		maxCap = 1
	}
	if listener == nil {
		return nil
	}
	return &Pool{
		conns:    sync.Map{},
		idChan:   make(chan string, maxCap),
		listener: listener,
	}
}

func (p *Pool) BrokerManager() {
	if p.cancel != nil {
		p.cancel()
	}
	p.ctx, p.cancel = context.WithCancel(context.Background())
	var mu sync.Mutex
	for {
		interval := p.interval
		select {
		case <-p.ctx.Done():
			return
		default:
			if !mu.TryLock() {
				continue
			}
			p.adjustInterval()
			created := 0
			for len(p.idChan) < p.capacity {
				conn, err := p.dialer()
				if err != nil {
					continue
				}
				id := p.getID()
				select {
				case p.idChan <- id:
					p.conns.Store(id, conn)
					created++
				default:
					conn.Close()
				}
			}
			p.adjustCapacity(created)
			mu.Unlock()
			time.Sleep(interval)
		}
	}
}

func (p *Pool) ClientManager() {
	if p.cancel != nil {
		p.cancel()
	}
	p.ctx, p.cancel = context.WithCancel(context.Background())
	var mu sync.Mutex
	for {
		select {
		case <-p.ctx.Done():
			return
		default:
			if !mu.TryLock() {
				continue
			}
			created := 0
			for len(p.idChan) < p.capacity {
				conn, err := p.dialer()
				if err != nil {
					continue
				}
				buf := make([]byte, 8)
				n, err := conn.Read(buf)
				if err != nil || n != 8 {
					conn.Close()
					continue
				}
				id := string(buf[:n])
				select {
				case p.idChan <- id:
					p.conns.Store(id, conn)
					created++
				default:
					conn.Close()
				}
			}
			p.adjustCapacity(created)
			mu.Unlock()
			time.Sleep(p.interval)
		}
	}
}

func (p *Pool) ServerManager() {
	if p.cancel != nil {
		p.cancel()
	}
	p.ctx, p.cancel = context.WithCancel(context.Background())
	for {
		select {
		case <-p.ctx.Done():
			return
		default:
			conn, err := p.listener.Accept()
			if err != nil {
				continue
			}
			id := p.getID()
			_, err = conn.Write([]byte(id))
			if err != nil {
				conn.Close()
				continue
			}
			select {
			case p.idChan <- id:
				p.conns.Store(id, conn)
			default:
				conn.Close()
			}
		}
	}
}

func (p *Pool) BrokerGet() (string, net.Conn) {
	for {
		select {
		case id := <-p.idChan:
			if conn, ok := p.conns.LoadAndDelete(id); ok {
				netConn := conn.(net.Conn)
				if p.isActive(netConn) {
					return id, netConn
				}
				netConn.Close()
			}
		case <-p.ctx.Done():
			return p.ctx.Err().Error(), nil
		default:
			conn, err := p.dialer()
			if err != nil {
				return err.Error(), nil
			}
			return p.getID(), conn
		}
	}
}

func (p *Pool) ClientGet(id string) net.Conn {
	p.mu.Lock()
	defer p.mu.Unlock()
	if conn, ok := p.conns.LoadAndDelete(id); ok {
		p.removeID(id)
		return conn.(net.Conn)
	}
	return nil
}

func (p *Pool) ServerGet() (string, net.Conn) {
	for {
		select {
		case id := <-p.idChan:
			if conn, ok := p.conns.LoadAndDelete(id); ok {
				netConn := conn.(net.Conn)
				if p.isActive(netConn) {
					return id, netConn
				}
				netConn.Close()
			}
		case <-p.ctx.Done():
			return p.ctx.Err().Error(), nil
		}
	}
}

func (p *Pool) Flush() {
	p.mu.Lock()
	defer p.mu.Unlock()
	var wg sync.WaitGroup
	p.conns.Range(func(key, value any) bool {
		wg.Add(1)
		go func() {
			defer wg.Done()
			value.(net.Conn).Close()
		}()
		return true
	})
	wg.Wait()
	p.conns = sync.Map{}
}

func (p *Pool) Close() {
	if p.cancel != nil {
		p.cancel()
	}
	p.Flush()
}

func (p *Pool) Ready() bool {
	return p.ctx != nil
}

func (p *Pool) Active() int {
	return len(p.idChan)
}

func (p *Pool) Capacity() int {
	return p.capacity
}

func (p *Pool) Interval() time.Duration {
	return p.interval
}

func (p *Pool) getID() string {
	bytes := make([]byte, 4)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

func (p *Pool) removeID(id string) {
	var wg sync.WaitGroup
	tmpChan := make(chan string, p.maxCap)
	for {
		select {
		case tmp := <-p.idChan:
			wg.Add(1)
			go func() {
				defer wg.Done()
				if tmp != id {
					tmpChan <- tmp
				}
			}()
		default:
			wg.Wait()
			p.idChan = tmpChan
			return
		}
	}
}

func (p *Pool) adjustInterval() {
	idle := len(p.idChan)
	if idle < p.capacity*2/10 && p.interval > p.minIvl {
		p.interval -= time.Second
	}
	if idle > p.capacity*8/10 && p.interval < p.maxIvl {
		p.interval += time.Second
	}
}

func (p *Pool) adjustCapacity(created int) {
	ratio := float64(created) / float64(p.capacity)
	if ratio < 0.2 && p.capacity > p.minCap {
		p.capacity--
	}
	if ratio > 0.8 && p.capacity < p.maxCap {
		p.capacity++
	}
}

func (p *Pool) isActive(conn net.Conn) bool {
	if err := conn.SetReadDeadline(time.Now().Add(time.Millisecond)); err != nil {
		return false
	}
	_, err := conn.Read(make([]byte, 1))
	if err := conn.SetReadDeadline(time.Time{}); err != nil {
		return false
	}
	if err, ok := err.(net.Error); ok && err.Timeout() {
		return true
	}
	return false
}
