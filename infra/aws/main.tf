locals {
  vpc_addr = "10.0.0.0/8"
  vpc_addrs = {
    "us-east-1" : cidrsubnet(local.vpc_addr, 8, 1),
    "us-west-1" : cidrsubnet(local.vpc_addr, 8, 2),
  }

}

provider "aws" {
  alias    = "by_region"
  region   = each.value
  for_each = var.regions
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
  source   = "./modules/cluster"
  for_each = setsubtract(var.regions, var.disabled_regions)
  providers = {
    aws = aws.by_region[each.key]
  }

  region   = each.key
  vpc_cidr = local.vpc_addrs[each.key]

  server = {
    count         = var.server_count
    instance_type = var.server_instance_type
    retry_join    = join(", ", [for value in concat(["${var.retry_join}"], [for peer_region in keys(local.vpc_addrs) : "${var.retry_join} region=${peer_region}" if peer_region != each.key]) : "\"${value}\""])
  }
  client = {
    count         = var.client_count
    instance_type = var.client_instance_type
    retry_join    = var.retry_join
  }

  public_key     = tls_private_key.pk.public_key_openssh
  peer_vpc_cidrs = [for peer_region, peer_vpc in local.vpc_addrs : peer_vpc if peer_region != each.key]

}


// ------------ create vpc peering connection ------------

resource "aws_vpc_peering_connection" "main" {
  vpc_id      = module.cluster["us-east-1"].vpc.vpc_id
  peer_vpc_id = module.cluster["us-west-1"].vpc.vpc_id
  peer_region = "us-west-1"
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.by_region["us-west-1"]
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true
}


resource "aws_route" "vpc_peer" {
  for_each = {
    for item in flatten([
      for region in var.regions : [
        for region2, addr in local.vpc_addrs : {
          region    = region
          peer_addr = addr
        } if region2 != region
      ]
    ]) : "${item.region}=>${item.peer_addr}" => item
  }
  provider                  = aws.by_region[each.value.region]
  route_table_id            = module.cluster[each.value.region].vpc.public_route_table_ids[0]
  destination_cidr_block    = each.value.peer_addr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

resource "aws_route_table_association" "east" {
  for_each       = setsubtract(var.regions, var.disabled_regions)
  subnet_id      = module.cluster[each.key].vpc.public_subnets[0]
  route_table_id = module.cluster[each.key].vpc.public_route_table_ids[0]
  provider       = aws.by_region[each.key]
}
