variable "aws_region" {
  description = "AWS region where the monitoring server will be created"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for Prometheus and Grafana"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size of the monitoring server root EBS volume in GiB"
  type        = number
  default     = 20
}

variable "allowed_ip" {
  description = "Public IPv4 address allowed to access SSH and Grafana"
  type        = string
}