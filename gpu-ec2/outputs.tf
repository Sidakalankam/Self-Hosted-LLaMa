output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.llama_server.id
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.llama_server.public_ip
}

output "ssh_command" {
  description = "Command used to SSH into the EC2 instance"
  value       = "ssh ubuntu@${aws_instance.llama_server.public_ip}"
}

output "vllm_url" {
  description = "URL of the vLLM API"
  value       = "http://${aws_instance.llama_server.public_ip}:8000"
}