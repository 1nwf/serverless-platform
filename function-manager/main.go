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
	"os/signal"
	"strings"
	"syscall"
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

type Cache struct {
	rdb  *redis.Client
	info InvokeInfo
}

func (c *Cache) AddInstance(ctx context.Context) error {
	key := "warm:" + c.info.functionName
	return c.rdb.LPush(ctx, key, c.info.allocId).Err()
}

func (c *Cache) RemInstance(ctx context.Context) error {
	key := "warm:" + c.info.functionName
	return c.rdb.LRem(ctx, key, 1, c.info.allocId).Err()
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
	cache := &Cache{
		rdb:  redisClient,
		info: info,
	}

	lis := NewListener(":3000")
	mux := http.NewServeMux()
	target, _ := url.Parse("http://localhost:8000")
	proxy := httputil.NewSingleHostReverseProxy(target)

	mux.HandleFunc("/{function}/invoke", func(w http.ResponseWriter, r *http.Request) {
		proxy.ServeHTTP(w, r)
		if err := cache.AddInstance(r.Context()); err != nil {
			log.Printf("failed to add instance from warm cache: %v", err)
		}
	})

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM)

	go func() {
		<-ch
		if err := cache.RemInstance(ctx); err != nil {
			log.Printf("failed to remove instance from warm cache: %v", err)
		}
		log.Printf("function terminated")
	}()

	server := http.Server{Handler: mux}
	// add instance to function's warm cache to start receiving requests
	if err := cache.AddInstance(ctx); err != nil {
		log.Printf("failed to add instance from warm cache: %v", err)
	}
	err := server.Serve(&lis)
	if err != nil && errors.Is(err, ErrTimeout) {
		log.Print("shutting down function instance due to timeout")
		if err := cache.RemInstance(ctx); err != nil {
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
