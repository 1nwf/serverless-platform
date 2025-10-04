locals {
  vpc_cidr = "10.0.0.0/16"
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    name = "main"
  }
}


resource "aws_subnet" "gateway" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, 1)
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
}


resource "aws_subnet" "cluster" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, 2)
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.rt.id
  subnet_id      = aws_subnet.gateway.id
}


resource "aws_eip" "nat" {}


resource "aws_nat_gateway" "gw" {
  connectivity_type = "public"
  subnet_id         = aws_subnet.cluster.id
  allocation_id     = aws_eip.nat.allocation_id


}

resource "aws_route_table" "nat" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw.id
  }
}


resource "aws_route_table_association" "nat" {
  route_table_id = aws_route_table.rt.id
  subnet_id      = aws_subnet.cluster.id
}
