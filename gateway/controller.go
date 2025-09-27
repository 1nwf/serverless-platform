package main

import (
	"context"
	"fmt"
	"log"

	"github.com/redis/go-redis/v9"
)

type Controller struct {
	rdb         *redis.Client
	nomadClient *NomadClient
}

func NewController(nomadClient *NomadClient, rdb *redis.Client) *Controller {
	return &Controller{rdb, nomadClient}
}

func (c *Controller) ClaimInstance(ctx context.Context, functionName string) (*JobInfo, error) {
	key := fmt.Sprintf("warm:%s", functionName)
	res, err := c.rdb.SPop(ctx, key).Result()
	if err != nil {
		return c.coldStartFunction(functionName)
	}

	log.Printf("found warm function instance for %s", functionName)
	info, err := c.nomadClient.GetAllocatonInfo(res)
	// TODO: ensure that allocation is running
	if err != nil {
		return nil, err
	}

	return info, nil
}

func (c *Controller) ReleaseInstance(ctx context.Context, functionName string, info *JobInfo) {
	key := fmt.Sprintf("warm:%s", functionName)
	c.rdb.SAdd(ctx, key, info.AllocId)
}

func (c *Controller) coldStartFunction(functionName string) (*JobInfo, error) {
	log.Printf("cold starting function %s", functionName)
	res, err := c.nomadClient.Displatch(functionName)
	if err != nil {
		return nil, err
	}
	info, err := c.nomadClient.BlockUntilJobRun(res.DispatchedJobID)
	return info, err
}
