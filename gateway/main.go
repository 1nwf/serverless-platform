package main

import "fmt"

func main() {
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
