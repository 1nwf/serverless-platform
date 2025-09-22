package main

import (
	"context"
	"errors"

	"github.com/hashicorp/nomad/api"
)

type NomadClient struct {
	client *api.Client
}

func NewNomadClient() (*NomadClient, error) {
	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		return nil, err
	}

	return &NomadClient{
		client: client,
	}, nil
}

func (n *NomadClient) RegisterJob(jobId string, dockerImage string) (*api.JobRegisterResponse, error) {
	// should set a dynamic network port env
	// that should be used by the container process
	task := api.NewTask(jobId, "docker").
		SetConfig("image", dockerImage).
		SetConfig("ports", []string{"addr"})

	taskGroup := api.NewTaskGroup(jobId, 1).AddTask(task)
	netCfg := &api.NetworkResource{
		Mode: "host",
		DynamicPorts: []api.Port{
			{
				Label: "addr",
				To:    6379,
			},
		},
	}
	taskGroup.Networks = append(taskGroup.Networks, netCfg)
	job := api.NewBatchJob(jobId, jobId, "", api.JobDefaultPriority).
		AddTaskGroup(taskGroup)
	job.ParameterizedJob = &api.ParameterizedJobConfig{}

	res, _, err := n.client.Jobs().Register(job, nil)
	if err != nil {
		return nil, err
	}

	return res, nil
}

func (n *NomadClient) Displatch(jobId string) (*api.JobDispatchResponse, error) {
	res, _, err := n.client.Jobs().Dispatch(jobId, nil, nil, "", nil)
	return res, err
}

func (n *NomadClient) ListRunningJobs(jobId string) ([]*api.JobListStub, error) {
	res, _, err := n.client.Jobs().List(&api.QueryOptions{
		Prefix: jobId + "/",
		Filter: `Status == "running"`,
	})
	return res, err

}

func (n *NomadClient) GetAllocation(jobId string) ([]*api.AllocationListStub, error) {
	res, _, err := n.client.Jobs().Allocations(jobId, true, nil)
	return res, err
}

type JobInfo struct {
	HostPort int
	NodeName string
}

func (n *NomadClient) BlockUntilJobRun(jobId string) (*JobInfo, error) {
	ctx, cancelFunc := context.WithCancel(context.Background())
	defer cancelFunc()

	topics := map[api.Topic][]string{
		api.TopicAllocation: {jobId},
	}

	events, err := n.client.EventStream().Stream(ctx, topics, 0, nil)
	if err != nil {
		return nil, err
	}

	for ev := range events {
		for _, value := range ev.Events {
			payload := value.Payload[string(api.TopicAllocation)].(map[string]any)
			status := payload["ClientStatus"]
			if status == api.AllocClientStatusRunning {
				allocatedPort := payload["Resources"].(map[string]any)["Networks"].([]any)[0].(map[string]any)["DynamicPorts"].([]any)[0].(map[string]any)["Value"].(float64)
				nodeName := payload["NodeName"].(string)
				return &JobInfo{
					HostPort: int(allocatedPort),
					NodeName: nodeName,
				}, nil
			}
		}
	}

	return nil, errors.New("unable to retrieve job status")
}
