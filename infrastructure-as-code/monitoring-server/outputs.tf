output "instance_id" {
  description = "Monitoring EC2 instance ID"
  value       = aws_instance.monitoring.id
}

output "public_ip" {
  description = "Elastic IPv4 address of the monitoring server"
  value       = aws_eip.monitoring.public_ip
}

output "private_ip" {
  description = "Private IPv4 address of the monitoring server"
  value       = aws_instance.monitoring.private_ip
}

output "ssh_command" {
  description = "Command used to SSH into the monitoring server"
  value       = "ssh ubuntu@${aws_eip.monitoring.public_ip}"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_eip.monitoring.public_ip}:3000"
}