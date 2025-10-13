resource "aws_instance" "server" {
  ami                    = var.ami
  instance_type          = var.server.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.server.vpc_security_group_ids
  count                  = var.server.count
  subnet_id              = var.subnet_id

  # instance tags
  # NomadAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-${var.region}-${var.datacenter}-server-${count.index}"
    },
    {
      "NomadAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "server"
    }
  )

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }


  user_data = templatefile("${path.module}/../../../shared/data-scripts/user-data-server.sh", {
    server_count = var.server.count
    region       = var.region
    datacenter   = var.datacenter
    cloud_env    = "aws"
    retry_join   = var.retry_join
    nomad_binary = var.nomad_binary
  })
  iam_instance_profile = var.iam_instance_profile

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.client.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.client.vpc_security_group_ids
  count                  = var.client.count
  depends_on             = [aws_instance.server]
  subnet_id              = var.subnet_id

  # instance tags
  # NomadAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-${var.region}-${var.datacenter}-client-${count.index}"
    },
    {
      "NomadAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  ebs_block_device {
    device_name           = "/dev/xvdd"
    volume_type           = "gp3"
    volume_size           = "50"
    delete_on_termination = "true"
  }

  user_data = templatefile("${path.module}/../../../shared/data-scripts/user-data-client.sh", {
    region       = var.region
    datacenter   = var.datacenter
    cloud_env    = "aws"
    retry_join   = var.retry_join
    nomad_binary = var.nomad_binary
  })
  iam_instance_profile = var.iam_instance_profile

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}
