# Find the latest official Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Discover the default VPC.
# The inference server currently lives in this VPC.
data "aws_vpc" "default" {
  default = true
}


# Register the same Mac SSH public key for the monitoring stack.
# This uses a different AWS key-pair name from the inference server,
# while using the same local public key.
resource "aws_key_pair" "monitoring" {
  key_name   = "llama-monitoring-key"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))

  tags = {
    Name = "llama-monitoring-key"
  }
}


# Security group for Prometheus and Grafana
resource "aws_security_group" "monitoring" {
  name        = "llama-monitoring-sg"
  description = "Security group for the Llama monitoring server"
  vpc_id      = data.aws_vpc.default.id

  # SSH access from my machine
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_ip}/32"]
  }

  # Grafana dashboard from my machine
  ingress {
    description = "Grafana from my IP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_ip}/32"]
  }

  # Prometheus does not need public ingress on port 9090.

  # Allow the monitoring server to make outbound connections.
  # Prometheus will use this to reach the vLLM server over the VPC.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "llama-monitoring-sg"
  }
}


# Create the monitoring EC2 instance
resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  associate_public_ip_address = true

  key_name = aws_key_pair.monitoring.key_name

  vpc_security_group_ids = [
    aws_security_group.monitoring.id
  ]

  # Require IMDSv2
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "llama-monitoring-server"
  }
}


# Allocate a static public IPv4 address for the monitoring server
resource "aws_eip" "monitoring" {
  domain = "vpc"

  tags = {
    Name = "llama-monitoring-eip"
  }
}


# Associate the Elastic IP with the monitoring EC2 instance
resource "aws_eip_association" "monitoring" {
  instance_id   = aws_instance.monitoring.id
  allocation_id = aws_eip.monitoring.id
}