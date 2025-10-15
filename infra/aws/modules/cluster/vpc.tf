locals {
  az_count             = 2
  private_subnet_start = 1
  private_subnet_end   = local.private_subnet_start + local.az_count
  public_subnet_start  = local.private_subnet_end
  public_subnet_end    = local.public_subnet_start + local.az_count

  private_subnets = [for num in range(local.private_subnet_start, local.private_subnet_end) : cidrsubnet(var.vpc_cidr, 8, num)]
  public_subnets  = [for num in range(local.public_subnet_start, local.public_subnet_end) : cidrsubnet(var.vpc_cidr, 8, num)]
}


data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "main"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, local.az_count)
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway      = true
  map_public_ip_on_launch = true
}
