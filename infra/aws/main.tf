locals {
  vpc_addr = "10.0.0.0/8"
  vpc_east = cidrsubnet(local.vpc_addr, 8, 1)
  vpc_west = cidrsubnet(local.vpc_addr, 8, 2)
}

provider "aws" {
  alias  = "us-east-1"
  region = var.region
}

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"
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

module "cluster_east" {
  source = "./modules/cluster"
  providers = {
    aws = aws.us-east-1
  }

  region     = "us-east-1"
  vpc_cidr   = local.vpc_east
  retry_join = var.retry_join

  server = {
    count         = var.server_count
    instance_type = var.server_instance_type
  }
  client = {
    count         = var.client_count
    instance_type = var.client_instance_type
  }

  public_key     = tls_private_key.pk.public_key_openssh
  peer_vpc_cidrs = [local.vpc_west]
}


module "cluster_west" {
  source = "./modules/cluster"
  providers = {
    aws = aws.us-west-1
  }

  region     = "us-west-1"
  vpc_cidr   = local.vpc_west
  retry_join = var.retry_join

  server = {
    count         = var.server_count
    instance_type = var.server_instance_type
  }
  client = {
    count         = var.client_count
    instance_type = var.client_instance_type
  }

  public_key     = tls_private_key.pk.public_key_openssh
  peer_vpc_cidrs = [local.vpc_east]
}


// ------------ create vpc peering connection ------------

resource "aws_vpc_peering_connection" "main" {
  vpc_id      = module.cluster_east.vpc.vpc_id
  peer_vpc_id = module.cluster_west.vpc.vpc_id
  peer_region = "us-west-1"
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.us-west-1
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true
}


resource "aws_route" "vpc_east_peer" {
  provider                  = aws.us-east-1
  route_table_id            = module.cluster_east.vpc.public_route_table_ids[0]
  destination_cidr_block    = local.vpc_west
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

resource "aws_route" "vpc_west_peer" {
  provider                  = aws.us-west-1
  route_table_id            = module.cluster_west.vpc.public_route_table_ids[0]
  destination_cidr_block    = local.vpc_east
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

resource "aws_route_table_association" "east" {
  subnet_id      = module.cluster_east.vpc.public_subnets[0]
  route_table_id = module.cluster_east.vpc.public_route_table_ids[0]
  provider       = aws.us-east-1
}

resource "aws_route_table_association" "west" {
  subnet_id      = module.cluster_west.vpc.public_subnets[0]
  route_table_id = module.cluster_west.vpc.public_route_table_ids[0]
  provider       = aws.us-west-1
}
