variable "name_prefix" {
  type    = string
  default = "nomad"
}

variable "retry_join" {
  description = "Used by Nomad to automatically form a cluster."
  type        = string
  default     = "provider=aws tag_key=NomadAutoJoin tag_value=auto-join"
}

variable "root_block_device_size" {
  description = "The volume size of the root block device."
  default     = 16
}

variable "nomad_binary" {
  description = "URL of a zip file containing a nomad executable to replace the Nomad binaries in the AMI with. Example: https://releases.hashicorp.com/nomad/0.10.0/nomad_0.10.0_linux_amd64.zip"
  default     = ""
}

variable "server" {
  type = object({
    instance_type = optional(string, "t2.micro")
    count         = optional(number, 3)
    retry_join    = string
  })
}


variable "client" {
  type = object({
    instance_type = optional(string, "t2.micro")
    count         = optional(number, 3)
    retry_join    = string
  })
}


variable "region" {
  type = string
}


variable "public_key" {
  type = string
}

variable "allowlist_ip" {
  description = "IP to allow access for the security groups (set 0.0.0.0/0 for world)"
  default     = "0.0.0.0/0"
}

variable "peer_vpc_cidrs" {
  description = "peer vpc cidrs"
  type        = set(string)
}


variable "vpc_cidr" {
  type = string
}
