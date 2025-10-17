data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"
region     = "REGION"
datacenter = "DATACENTER"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = SERVER_COUNT

  server_join {
    retry_join = [RETRY_JOIN]
  }
}



acl {
  enabled = true
}

