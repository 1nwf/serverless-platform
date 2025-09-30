package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/{function}/invoke", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "function response")
	})

	if err := http.ListenAndServe("localhost:8000", mux); err != nil {
		log.Fatalf("error: %v", err)
	}
}
