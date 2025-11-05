terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-lakshans-1"
    key            = "s3-writer-example/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_iam_user" "writer" {
  name = var.aws_user_name
}

resource "aws_iam_access_key" "writer_key" {
  user = aws_iam_user.writer.name
}

resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_policy" "write_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ],
        Resource = "${aws_s3_bucket.bucket.arn}/*",
        Principal = {
          AWS = aws_iam_user.writer.arn
        }
      }
    ]
  })
}
