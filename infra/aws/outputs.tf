output "server_public_ips" {
  value = {
    for region in setsubtract(var.regions, var.disabled_regions) : region =>
    flatten(module.cluster[region].nomad_server_public_ips)
  }
}
