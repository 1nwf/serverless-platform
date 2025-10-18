variable "name_prefix" {
  description = "Prefix used to name various infrastructure components. Alphanumeric characters only."
  default     = "nomad"
}

variable "regions" {
  description = "The AWS regions to deploy to."
  type        = set(string)
}

variable "retry_join" {
  description = "Used by Nomad to automatically form a cluster."
  type        = string
  default     = "provider=aws tag_key=NomadAutoJoin tag_value=auto-join"
}

variable "allowlist_ip" {
  description = "IP to allow access for the security groups (set 0.0.0.0/0 for world)"
  default     = "0.0.0.0/0"
}

variable "server_instance_type" {
  description = "The AWS instance type to use for servers."
  default     = "t2.micro"
}

variable "client_instance_type" {
  description = "The AWS instance type to use for clients."
  default     = "t2.micro"
}

variable "server_count" {
  default     = 3
  type        = number
  description = "The number of servers to provision."
}

variable "client_count" {
  default     = 3
  type        = number
  description = "The number of clients to provision."
}

variable "root_block_device_size" {
  description = "The volume size of the root block device."
  default     = 16
}

variable "nomad_binary" {
  description = "URL of a zip file containing a nomad executable to replace the Nomad binaries in the AMI with. Example: https://releases.hashicorp.com/nomad/0.10.0/nomad_0.10.0_linux_amd64.zip"
  default     = ""
}

variable "disabled_regions" {
  type    = set(string)
  default = []
}
