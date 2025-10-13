output "IP_Addresses" {
  value = <<CONFIGURATION

Client public IPs: ${join(", ", module.cluster.client_public_ips)}

Server public IPs: ${join(", ", module.cluster.server_public_ips)}

The Nomad UI can be accessed at http://${module.cluster.server_public_ips[0]}:4646/ui
CONFIGURATION
}
