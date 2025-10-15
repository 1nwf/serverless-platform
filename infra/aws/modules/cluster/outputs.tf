output "nomad_server_public_ips" {
  value = module.nomad[*].server_public_ips
}

output "vpc" {
  value = module.vpc
}
