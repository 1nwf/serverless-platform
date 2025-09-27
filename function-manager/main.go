package main

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	ErrTimeout = errors.New("listener timeout")
)

type InvokeInfo struct {
	allocId      string
	functionName string
}

func invokeInfo() InvokeInfo {
	allocId := os.Getenv("NOMAD_ALLOC_ID")
	jobId := os.Getenv("NOMAD_JOB_ID")
	idx := strings.IndexRune(jobId, '/')
	functionName := jobId[:idx]
	return InvokeInfo{
		allocId,
		functionName,
	}
}

func main() {
	ctx := context.Background()
	info := invokeInfo()
	log.Printf("invocation info: %v", info)
	redisAddr := os.Getenv("REDIS_ADDR")
	redisClient := redis.NewClient(&redis.Options{
		Addr: redisAddr,
		DB:   0,
	})

	lis := NewListener(":3000")
	mux := http.NewServeMux()
	target, _ := url.Parse("http://localhost:8000")
	proxy := httputil.NewSingleHostReverseProxy(target)

	mux.HandleFunc("/{function}/invoke", func(w http.ResponseWriter, r *http.Request) {
		proxy.ServeHTTP(w, r)
	})

	server := http.Server{Handler: mux}
	err := server.Serve(&lis)
	if err != nil && errors.Is(err, ErrTimeout) {
		if err := redisClient.SRem(ctx, "warm:"+info.functionName, info.allocId).Err(); err != nil {
			log.Printf("failed to remove instance from warm cache: %v", err)
		}

		if err := server.Shutdown(ctx); err != nil {
			log.Fatalf("server failed to shutdown gracefully: %v", err)
		}
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
