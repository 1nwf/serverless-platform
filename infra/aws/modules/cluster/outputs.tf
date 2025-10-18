output "nomad_server_public_ips" {
  value = module.nomad[*].server_public_ips
}

output "vpc" {
  value = module.vpc
}

output "lb_dns_name" {
  value = aws_alb.api_alb.dns_name
}

