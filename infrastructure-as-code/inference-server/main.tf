# Find the latest official Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  # Canonical's AWS account ID
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Find the monitoring server security group
data "aws_security_group" "monitoring" {
  filter {
    name   = "group-name"
    values = ["llama-monitoring-sg"]
  }

  filter {
    name   = "vpc-id"
    values = ["vpc-09191a25275821b08"]
  }
}

# Register our existing Mac SSH public key with AWS
resource "aws_key_pair" "llama_server" {
  key_name   = "llama-vllm-key"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))

  tags = {
    Name = "llama-vllm-key"
  }
}


# Control network access to the EC2 instance
resource "aws_security_group" "llama_server" {
  name        = "llama-vllm-sg"
  description = "Security group for the Llama vLLM server"

  # SSH
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_ip}/32"]
  }

  # vLLM OpenAI-compatible API
  ingress {
    description = "vLLM API from my IP"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_ip}/32"]
  }

  # Prometheus on the monitoring EC2
  ingress {
    description     = "vLLM metrics from monitoring server"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [data.aws_security_group.monitoring.id]
  }

  # Allow the EC2 instance to make outbound connections
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "llama-vllm-sg"
  }
}


# Create the GPU EC2 instance
resource "aws_instance" "llama_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  associate_public_ip_address = true

  key_name = aws_key_pair.llama_server.key_name

  vpc_security_group_ids = [
    aws_security_group.llama_server.id
  ]

  iam_instance_profile = aws_iam_instance_profile.llama_server.name

  # Require IMDSv2.
  # Hop limit 2 allows containers on the instance to access
  # credentials supplied through the EC2 instance role.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "llama-vllm-server"
  }
}

# Allocate a static public IPv4 address
resource "aws_eip" "llama_server" {
  domain = "vpc"

  tags = {
    Name = "llama-vllm-eip"
  }
}


# Associate the Elastic IP with the Llama EC2 instance
resource "aws_eip_association" "llama_server" {
  instance_id   = aws_instance.llama_server.id
  allocation_id = aws_eip.llama_server.id
}
