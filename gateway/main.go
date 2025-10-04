package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"

	"github.com/gorilla/mux"
	"github.com/redis/go-redis/v9"
)

func main() {
	redisAddr := os.Getenv("REDIS_ADDR")
	log.Printf("redis addr: %v", redisAddr)
	redisClient := redis.NewClusterClient(&redis.ClusterOptions{
		Addrs: []string{redisAddr},
		TLSConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
	})

	client, err := NewNomadClient()
	if err != nil {
		panic(err)
	}

	startServer(NewController(client, redisClient))
}

func startServer(controller *Controller) {
	r := mux.NewRouter()
	r.HandleFunc("/{function}/invoke", invokeHandler(controller))
	r.HandleFunc("/register", registerFunction(controller)).Methods(http.MethodPost)
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
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		targetUrl, err := url.Parse(fmt.Sprintf("http://%s:%d", info.NodeName, info.Port))
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		ProxyRequest(targetUrl, w, r)
	}
}

type RegisterFunctionRequest struct {
	FunctionName string            `json:"function_name"`
	DockerImage  string            `json:"docker_image"`
	Resources    FunctionResources `json:"resources"`
}

func registerFunction(ctrl *Controller) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		decoder := json.NewDecoder(r.Body)
		var body RegisterFunctionRequest
		if err := decoder.Decode(&body); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		log.Printf("register function: %v", body)
		if err := ctrl.RegisterFunction(body.FunctionName, body.DockerImage, body.Resources); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
	}
}
