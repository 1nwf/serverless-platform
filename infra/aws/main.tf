locals {
  vpc_cidr = "10.0.0.0/16"
}

provider "aws" {
  region = var.region
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "nomad_key" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "./nomad-aws-key-pair.pem"
  file_permission = "0400"
}

module "cluster" {
  source     = "./modules/cluster"
  vpc_cidr   = local.vpc_cidr
  retry_join = var.retry_join
  region     = var.region
  server = {
    count         = 1
    instance_type = var.server_instance_type
  }
  client = {
    count         = var.client_count
    instance_type = var.client_instance_type
  }
  public_key = tls_private_key.pk.public_key_openssh
}
