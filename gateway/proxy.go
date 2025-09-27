package main

import (
	"net/http"
	"net/http/httputil"
	"net/url"
)

func ProxyRequest(target *url.URL, w http.ResponseWriter, req *http.Request) {
	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.ServeHTTP(w, req)
}
