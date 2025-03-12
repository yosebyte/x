package pool

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net"
	"sync"
	"time"
)

type Pool struct {
	conns    *sync.Map
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
		conns:    &sync.Map{},
		idChan:   make(chan string, maxCap),
		dialer:   dialer,
		capacity: minCap,
		minCap:   minCap,
		maxCap:   maxCap,
		interval: time.Second,
	}
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
		conns:    &sync.Map{},
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

func NewServerPool(maxCap int, listener net.Listener) *Pool {
	if maxCap <= 0 {
		maxCap = 1
	}
	if listener == nil {
		return nil
	}
	return &Pool{
		conns:    &sync.Map{},
		idChan:   make(chan string, maxCap),
		listener: listener,
	}
}

func (p *Pool) ClientManager() {
	if p.cancel != nil {
		p.cancel()
	}
	p.ctx, p.cancel = context.WithCancel(context.Background())
	var mu sync.Mutex
	for {
		timer := time.NewTimer(p.interval)
		select {
		case <-timer.C:
			if !mu.TryLock() {
				continue
			}
			created := 0
			for len(p.idChan) < p.capacity {
				conn, err := p.dialer()
				if err != nil {
					break
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
		case <-p.ctx.Done():
			timer.Stop()
			return
		}
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
		timer := time.NewTimer(interval)
		select {
		case <-timer.C:
			if !mu.TryLock() {
				continue
			}
			p.adjustInterval()
			created := 0
			for len(p.idChan) < p.capacity {
				conn, err := p.dialer()
				if err != nil {
					break
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
		case <-p.ctx.Done():
			timer.Stop()
			return
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

func (p *Pool) getID() string {
	bytes := make([]byte, 4)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

func (p *Pool) adjustInterval() {
	idle := len(p.idChan)
	if idle < p.capacity*2/10 && p.interval > p.minIvl {
		p.interval -= time.Second
	} else if idle > p.capacity*8/10 && p.interval < p.maxIvl {
		p.interval += time.Second
	}
}

func (p *Pool) adjustCapacity(created int) {
	ratio := float64(created) / float64(p.capacity)
	if ratio > 0.8 && p.capacity < p.maxCap {
		p.capacity++
	} else if ratio < 0.2 && p.capacity > p.minCap {
		p.capacity--
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

func (p *Pool) Get() (string, net.Conn) {
	for {
		select {
		case id := <-p.idChan:
			if conn, ok := p.conns.Load(id); ok {
				netConn := conn.(net.Conn)
				if p.isActive(netConn) {
					return id, netConn
				}
				netConn.Close()
				p.conns.Delete(id)
			}
		case <-p.ctx.Done():
			return "", nil
		}
	}
}

func (p *Pool) GetMore() (string, net.Conn) {
	for {
		select {
		case id := <-p.idChan:
			if conn, ok := p.conns.Load(id); ok {
				netConn := conn.(net.Conn)
				if p.isActive(netConn) {
					return id, netConn
				}
				netConn.Close()
				p.conns.Delete(id)
			}
		case <-p.ctx.Done():
			return "", nil
		default:
			conn, err := p.dialer()
			if err != nil {
				return "", nil
			}
			return p.getID(), conn
		}
	}
}

func (p *Pool) Close() {
	if p.cancel != nil {
		p.cancel()
	}
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
