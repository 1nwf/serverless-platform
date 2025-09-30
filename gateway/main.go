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
	redisAddr = "host.docker.internal:6379"
)

func main() {
	redisClient := redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
		DB:   0,
	})
	_ = redisClient
	client, err := NewNomadClient()
	if err != nil {
		panic(err)
	}

	jobId := "function"
	env := map[string]string{"REDIS_ADDR": redisAddr}
	_, err = client.RegisterJob(jobId, "test-fn:local", env)
	if err != nil {
		panic(err)
	}

	startServer(NewController(client, redisClient))
}

func startServer(controller *Controller) {
	r := mux.NewRouter()
	r.HandleFunc("/{function}/invoke", invokeHandler(controller))
	log.Print("starting server on :8080")
	if err := http.ListenAndServe(":8080", r); err != nil {
		panic(err)
	}
}

func invokeHandler(ctrl *Controller) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		vars := mux.Vars(r)
		functionName := vars["function"]
		log.Printf("%s function invoked", functionName)
		info, err := ctrl.ClaimInstance(r.Context(), functionName)
		defer ctrl.ReleaseInstance(r.Context(), functionName, info)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		targetUrl, err := url.Parse(fmt.Sprintf("http://%s:%d", info.NodeName, 8000))
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		ProxyRequest(targetUrl, w, r)
	}
}
