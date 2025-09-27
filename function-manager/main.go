package main

import (
	"errors"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"time"
)

var (
	ErrTimeout = errors.New("listener timeout")
)

func main() {
	lis := NewListener(":3000")

	mux := http.NewServeMux()
	target, _ := url.Parse("http://localhost:8000")
	proxy := httputil.NewSingleHostReverseProxy(target)
	mux.HandleFunc("/{function}/invoke", func(w http.ResponseWriter, r *http.Request) {
		proxy.ServeHTTP(w, r)
	})

	err := http.Serve(&lis, mux)
	if err != nil && errors.Is(err, ErrTimeout) {
		// deregister container
	}
}

type Listener struct {
	tcpListener *net.TCPListener
}

func NewListener(address string) Listener {
	addr, _ := net.ResolveTCPAddr("tcp", address)
	lis, _ := net.ListenTCP("tcp", addr)
	return Listener{
		tcpListener: lis,
	}
}

func (lis *Listener) Accept() (net.Conn, error) {
	deadline := time.Now().Add(time.Minute * 10)
	if err := lis.tcpListener.SetDeadline(deadline); err != nil {
		return nil, err
	}

	conn, err := lis.tcpListener.Accept()
	// return custom error on timeout to prevent
	// go http server method from retrying on timeouts
	if err != nil && errors.Is(err, os.ErrDeadlineExceeded) {
		return nil, ErrTimeout
	}
	return conn, err
}

func (lis Listener) Close() error {
	return lis.tcpListener.Close()
}

func (lis *Listener) Addr() net.Addr {
	return lis.tcpListener.Addr()
}
