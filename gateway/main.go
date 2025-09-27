package main

import (
	"fmt"
	"log"
	"net/http"
	"net/url"

	"github.com/gorilla/mux"
	"github.com/redis/go-redis/v9"
)

const (
	redisAddr = "localhost:6379"
)

func main() {
	redisClient := redis.NewClient(&redis.Options{
		Addr: redisAddr,
		DB:   0,
	})
	_ = redisClient
	client, err := NewNomadClient()
	if err != nil {
		panic(err)
	}

	jobId := "function"
	res, err := client.RegisterJob(jobId, "redis:latest")
	if err != nil {
		panic(err)
	}
	fmt.Println(res)

	for range 1 {
		res, err := client.Displatch(jobId)
		if err != nil {
			panic(err)
		}
		fmt.Println(res)
		info, err := client.BlockUntilJobRun(res.DispatchedJobID)
		if err != nil {
			panic(err)
		}
		fmt.Println(info)
	}
}

func startServer(controller *Controller) {
	r := mux.NewRouter()
	r.HandleFunc("/{function}/invoke", invokeHandler(controller))
	log.Print("starting server on :3000")
	if err := http.ListenAndServe(":3000", r); err != nil {
		panic(err)
	}
}

func invokeHandler(ctrl *Controller) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		vars := mux.Vars(r)
		functionName := vars["function"]
		log.Printf("%s function invoked", functionName)
		info, err := ctrl.GetAvailHost(functionName)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		targetUrl, err := url.Parse(fmt.Sprintf("http://%s:%d", info.NodeName, info.HostPort))
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		ProxyRequest(targetUrl, w, r)
	}
}
