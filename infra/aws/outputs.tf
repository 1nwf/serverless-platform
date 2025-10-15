output "us_east_server_public_ips" {
  value = module.cluster_east.nomad_server_public_ips
}

output "us_west_server_public_ips" {
  value = module.cluster_west.nomad_server_public_ips
}
