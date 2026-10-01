variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the vLLM server"
  type        = string
  default     = "g5.xlarge"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB"
  type        = number
  default     = 100
}

variable "allowed_ip" {
  description = "Public IPv4 address allowed to access SSH and the vLLM API"
  type        = string
}