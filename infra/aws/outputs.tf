output "lb_address_nomad" {
  value = "http://${aws_instance.server[0].public_ip}"
}

output "IP_Addresses" {
  value = <<CONFIGURATION

Client public IPs: ${join(", ", aws_instance.client[*].public_ip)}

Server public IPs: ${join(", ", aws_instance.server[*].public_ip)}

The Nomad UI can be accessed at http://${aws_instance.server[0].public_ip}:4646/ui
CONFIGURATION
}
