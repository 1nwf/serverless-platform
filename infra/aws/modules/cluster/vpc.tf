locals {
  azs                  = ["a", "b", "c"]
  private_subnet_start = 1
  private_subnet_end   = local.private_subnet_start + length(local.azs)
  public_subnet_start  = local.private_subnet_end
  public_subnet_end    = local.public_subnet_start + length(local.azs)

  private_subnets = [for num in range(local.private_subnet_start, local.private_subnet_end) : cidrsubnet(var.vpc_cidr, 8, num)]
  public_subnets  = [for num in range(local.public_subnet_start, local.public_subnet_end) : cidrsubnet(var.vpc_cidr, 8, num)]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "main"
  cidr = var.vpc_cidr

  azs             = [for az in local.azs : "${var.region}${az}"]
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway      = true
  map_public_ip_on_launch = true
}
