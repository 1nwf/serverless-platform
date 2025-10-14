output "server_public_ips" {
  value = aws_instance.server[*].public_ip
}
