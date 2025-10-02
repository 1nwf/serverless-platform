package main

import (
	"context"
	"fmt"
	"log"
	"time"

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
	res, err := c.rdb.LPop(ctx, key).Result()
	if err != nil {
		return c.coldStartFunction(ctx, functionName)
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

func (c *Controller) coldStartFunction(ctx context.Context, functionName string) (*JobInfo, error) {
	log.Printf("cold starting function %s", functionName)
	_, err := c.nomadClient.Displatch(functionName)
	if err != nil {
		return nil, err
	}
	key := fmt.Sprintf("warm:%s", functionName)
	res, err := c.rdb.BLPop(ctx, time.Second*10, key).Result()
	if err != nil {
		log.Printf("redis error: %v", err)
		return nil, err
	}
	info, err := c.nomadClient.GetAllocatonInfo(res[1])
	return info, err
}
