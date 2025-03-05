package con

import (
	"context"
	"net"
	"sync"
	"time"
)

type Pool struct {
	mu       sync.Mutex
	conns    chan net.Conn
	factory  func() (net.Conn, error)
	capacity int
	minCap   int
	maxCap   int
	created  int
	interval time.Duration
	ctx      context.Context
	cancel   context.CancelFunc
}

func NewPool(minCap, maxCap int, factory func() (net.Conn, error)) *Pool {
	return &Pool{
		conns:    make(chan net.Conn, maxCap),
		factory:  factory,
		capacity: minCap,
		minCap:   minCap,
		maxCap:   maxCap,
		interval: time.Second,
	}
}

func (p *Pool) Manager() {
	if p.cancel != nil {
		p.cancel()
	}
	p.ctx, p.cancel = context.WithCancel(context.Background())
	for {
		interval := p.interval
		timer := time.NewTimer(interval)
		select {
		case <-timer.C:
			p.mu.Lock()
			p.adjustInterval()
			created := 0
			for len(p.conns) < p.capacity {
				conn, err := p.factory()
				if err != nil {
					break
				}
				p.conns <- conn
				created++
			}
			created += p.created
			p.created = 0
			p.adjustCapacity(created)
			p.mu.Unlock()
		case <-p.ctx.Done():
			timer.Stop()
			return
		}
	}
}

func (p *Pool) adjustInterval() {
	idle := len(p.conns)
	if idle < p.capacity*2/10 && p.interval > time.Second {
		p.interval -= time.Second
	} else if idle > p.capacity*8/10 && p.interval < time.Minute {
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

func (p *Pool) Get() (net.Conn, error) {
	for {
		select {
		case conn := <-p.conns:
			if p.isAlive(conn) {
				return conn, nil
			}
			conn.Close()
		default:
			p.mu.Lock()
			p.created++
			p.mu.Unlock()
			return p.factory()
		}
	}
}

func (p *Pool) isAlive(conn net.Conn) bool {
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

func (p *Pool) Stop() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.cancel != nil {
		p.cancel()
	}
	var wg sync.WaitGroup
	for len(p.conns) > 0 {
		conn := <-p.conns
		wg.Add(1)
		go func(c net.Conn) {
			defer wg.Done()
			c.Close()
		}(conn)
	}
	wg.Wait()
}

func (p *Pool) Close() {
	close(p.conns)
}

func (p *Pool) Active() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.conns)
}

func (p *Pool) Capacity() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.capacity
}

func (p *Pool) Interval() time.Duration {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.interval
}
