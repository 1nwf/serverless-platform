package main

import "github.com/redis/go-redis/v9"

type Controller struct {
	rdb         *redis.Client
	nomadClient *NomadClient
}

func NewController(nomadClient *NomadClient, rdb *redis.Client) *Controller {
	return &Controller{rdb, nomadClient}
}

func (c *Controller) GetAvailHost(functionName string) (*JobInfo, error) {
	panic("todo")
}
