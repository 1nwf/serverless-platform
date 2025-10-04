package main

import (
	"context"
	"errors"

	"github.com/hashicorp/nomad/api"
)

const (
	FunctionPort         = 3000
	FunctionManagerImage = "nwf1/fn-manager"
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

type FunctionResources struct {
	Cpu       *int `json:"cpu"`
	Memory    *int `json:"mem"`
	MemoryMax *int `json:"mem_max"`
}

func (n *NomadClient) RegisterJob(
	jobId string,
	dockerImage string,
	env map[string]string,
	resources FunctionResources,
) (*api.JobRegisterResponse, error) {
	// should set a dynamic network port env
	// that should be used by the container process
	portLabel := "http"
	sidecarTask := api.NewTask("manager", "docker").
		SetConfig("image", FunctionManagerImage).
		SetConfig("ports", []string{portLabel}).
		SetLifecycle(&api.TaskLifecycle{
			Hook: api.TaskLifecycleHookPoststart,
		})
	sidecarTask.Env = env
	sidecarTask.Leader = true

	task := api.NewTask(jobId, "docker").
		SetConfig("image", dockerImage)
	task.Resources.MemoryMB = resources.Memory
	task.Resources.MemoryMaxMB = resources.MemoryMax
	task.Resources.CPU = resources.Cpu

	taskGroup := api.NewTaskGroup(jobId, 1).AddTask(sidecarTask).AddTask(task)
	// disable auto restarts on task failure
	restartAttempts := 0
	restartMode := "fail"
	// disable restarts and rescheduling on failure
	taskGroup.ReschedulePolicy = &api.ReschedulePolicy{
		Attempts: &restartAttempts,
	}
	taskGroup.RestartPolicy = &api.RestartPolicy{
		Attempts: &restartAttempts,
		Mode:     &restartMode,
	}
	netCfg := &api.NetworkResource{
		Mode: "bridge",
		DynamicPorts: []api.Port{
			{
				Label: portLabel,
				To:    FunctionPort,
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
	JobId    string
	AllocId  string
	Port     int
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
			alloc, err := value.Allocation()
			if alloc.ClientStatus == api.AllocClientStatusRunning {
				if err != nil {
					return nil, err
				}
				allocatedPort := alloc.Resources.Networks[0].DynamicPorts[0].Value
				return &JobInfo{
					JobId:    jobId,
					AllocId:  alloc.ID,
					Port:     allocatedPort,
					NodeName: alloc.NodeName,
				}, nil
			}
		}
	}

	return nil, errors.New("unable to retrieve job status")
}

func (n *NomadClient) StopJob(jobId string) error {
	if _, _, err := n.client.Jobs().Deregister(jobId, true, nil); err != nil {
		return err
	}

	return nil
}

func (n *NomadClient) GetAllocatonInfo(allocId string) (*JobInfo, error) {
	alloc, _, err := n.client.Allocations().Info(allocId, nil)
	if err != nil {
		return nil, err
	}

	port := alloc.Resources.Networks[0].DynamicPorts[0].Value
	return &JobInfo{
		JobId:    alloc.JobID,
		AllocId:  allocId,
		Port:     port,
		NodeName: alloc.NodeName,
	}, nil
}
