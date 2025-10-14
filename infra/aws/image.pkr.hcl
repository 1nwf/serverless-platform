packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3.1"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

variable "regions" {
  type = set(string)
}

data "amazon-ami" "ami" {
  filters = {
    architecture                       = "x86_64"
    "block-device-mapping.volume-type" = "gp3"
    name                               = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    root-device-type                   = "ebs"
    virtualization-type                = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
}


source "amazon-ebs" "src" {
  ami_name              = "src-${local.timestamp}"
  instance_type         = "t2.medium"
  source_ami            = data.amazon-ami.ami.id
  ssh_username          = "ubuntu"
  force_deregister      = true
  force_delete_snapshot = true
  ami_regions           = var.regions


  tags = {
    Name          = "nomad"
    OS_Version    = "Ubuntu"
    Release       = "Latest"
    Base_AMI_ID   = "{{ .SourceAMI }}"
    Base_AMI_Name = "{{ .SourceAMIName }}"
  }

  snapshot_tags = {
    Name = "nomad"
  }
}

build {
  sources = ["source.amazon-ebs.src"]

  provisioner "shell" {
    inline = ["sudo mkdir -p /ops/shared", "sudo chmod 777 -R /ops"]
  }

  provisioner "file" {
    destination = "/ops"
    source      = "../shared"
  }

  provisioner "shell" {
    environment_vars = ["INSTALL_NVIDIA_DOCKER=false", "CLOUD_ENV=aws"]
    script           = "../shared/scripts/setup.sh"
  }

}
