output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}
output "access_key" {
  value     = aws_iam_access_key.writer_key.id
  sensitive = true
}

output "secret_key" {
  value     = aws_iam_access_key.writer_key.secret
  sensitive = true
}

output "s3_connection_url" {
  value = "s3://${aws_s3_bucket.bucket.bucket}"
}
