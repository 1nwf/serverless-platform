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
    count                  = optional(number, 3)
    instance_type          = optional(string, "t2.micro")
    subnet_id              = string
    vpc_security_group_ids = set(string)
    bootstrap_expect       = number
    retry_join             = string
  })
}


variable "client" {
  type = object({
    count                  = optional(number, 3)
    instance_type          = optional(string, "t2.micro")
    subnet_id              = string
    vpc_security_group_ids = set(string)
    retry_join             = string
  })
}


variable "key_name" {
  description = "Key name of the Key Pair to use for the instance"
  type        = string
}


variable "ami" {
  type = string
}

variable "region" {
  type = string
}

variable "datacenter" {
  type = string
}


variable "iam_instance_profile" {
  description = "IAM Instance Profile to launch the instances with"
  type        = string
}
