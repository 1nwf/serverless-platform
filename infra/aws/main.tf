provider "aws" {
  region = var.region
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "nomad" {
  key_name   = "nomad-aws-key-pair"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "nomad_key" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "./nomad-aws-key-pair.pem"
  file_permission = "0400"
}

module "cluster" {
  source     = "./modules/cluster"
  retry_join = var.retry_join
  region     = var.region
  server = {
    count                  = var.server_count
    instance_type          = var.server_instance_type
    vpc_security_group_ids = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.allow_all_internal.id]
  }
  client = {
    count                  = var.client_count
    instance_type          = var.client_instance_type
    vpc_security_group_ids = [aws_security_group.ssh_ingress.id, aws_security_group.clients_ingress.id]
  }
  ami                  = var.ami
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  key_name             = aws_key_pair.nomad.key_name
  subnet_id            = aws_subnet.cluster.id
  datacenter           = aws_subnet.cluster.availability_zone
}

resource "aws_elasticache_serverless_cache" "functions" {
  engine               = "valkey"
  name                 = "functions"
  subnet_ids           = [aws_subnet.gateway.id, aws_subnet.cluster.id]
  security_group_ids   = [aws_security_group.cache.id]
  major_engine_version = "8"
  cache_usage_limits {
    data_storage {
      maximum = "10"
      unit    = "GB"
    }
  }
}

resource "aws_instance" "gateway" {
  ami                    = var.ami
  instance_type          = var.server_instance_type
  key_name               = aws_key_pair.nomad.key_name
  vpc_security_group_ids = [aws_security_group.gatway.id, aws_security_group.ssh_ingress.id, aws_security_group.allow_all_internal.id]
  count                  = 1
  subnet_id              = aws_subnet.gateway.id

  # instance tags
  tags = merge(
    {
      "Name" = "${var.name_prefix}-gateway-${count.index}"
    },
  )

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
}
