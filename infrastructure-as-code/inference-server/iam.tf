# IAM role that the EC2 instance can assume
resource "aws_iam_role" "llama_server" {
  name = "llama-vllm-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "llama-vllm-ec2-role"
  }
}


# Allow the EC2 instance to read the Llama model from S3
resource "aws_iam_role_policy" "llama_s3_read" {
  name = "llama-model-s3-read"
  role = aws_iam_role.llama_server.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = "arn:aws:s3:::personal-llm-registry"

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "models/llama-3.1-8b-instruct",
              "models/llama-3.1-8b-instruct/*"
            ]
          }
        }
      },

      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "arn:aws:s3:::personal-llm-registry/models/llama-3.1-8b-instruct/*"
      }
    ]
  })
}


# Instance profiles are how an IAM role gets attached to EC2
resource "aws_iam_instance_profile" "llama_server" {
  name = "llama-vllm-instance-profile"
  role = aws_iam_role.llama_server.name
}