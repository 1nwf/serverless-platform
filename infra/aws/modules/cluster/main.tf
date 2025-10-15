resource "aws_key_pair" "nomad" {
  key_name   = "nomad-aws-key-pair"
  public_key = var.public_key
}

data "aws_ami" "nomad" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["src-*"]
  }
}


module "nomad" {
  source = "./nomad"
  count  = length(module.vpc.private_subnets)

  retry_join = var.retry_join
  region     = var.region
  server = {
    bootstrap_expect       = var.server.count * length(module.vpc.private_subnets)
    count                  = var.server.count
    instance_type          = var.server.instance_type
    subnet_id              = module.vpc.public_subnets[count.index]
    vpc_security_group_ids = [aws_security_group.allow_peer_vpcs.id, aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.allow_all_internal.id]
  }
  client = {
    count                  = var.client.count
    instance_type          = var.client.instance_type
    subnet_id              = module.vpc.private_subnets[count.index]
    vpc_security_group_ids = [aws_security_group.ssh_ingress.id, aws_security_group.clients_ingress.id]
  }
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  key_name             = aws_key_pair.nomad.key_name
  datacenter           = module.vpc.private_subnet_objects[count.index].availability_zone
  ami                  = data.aws_ami.nomad.id
}


resource "aws_elasticache_serverless_cache" "functions" {
  engine               = "valkey"
  name                 = "functions"
  subnet_ids           = module.vpc.private_subnets
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
  ami                    = data.aws_ami.nomad.id
  instance_type          = var.server.instance_type
  key_name               = aws_key_pair.nomad.key_name
  vpc_security_group_ids = [aws_security_group.gatway.id, aws_security_group.ssh_ingress.id, aws_security_group.allow_all_internal.id]
  count                  = 1
  subnet_id              = module.vpc.private_subnets[0]

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
