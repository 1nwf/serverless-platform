data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
region = "REGION"
datacenter = "DATACENTER"

# Enable the client
client {
  enabled = true
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }

  server_join {
    retry_join = ["RETRY_JOIN"]
  }
  
}

acl {
  enabled = true
}

