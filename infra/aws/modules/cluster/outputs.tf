output "client_public_ips" {
  value = aws_instance.client[*].public_ip
}


output "server_public_ips" {
  value = aws_instance.server[*].public_ip
}
