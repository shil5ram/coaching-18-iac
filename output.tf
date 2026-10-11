output "aws_role_arn_to_use_in_github" {
  value       = aws_iam_role.github_actions_role.arn
  description = "Copy this ARN value directly into your GitHub Actions workflow configuration"
}

output "flaskapp_s3_bucket_name" {
  value = aws_s3_bucket.flask_bucket.id
}

output "flaskapp_sqs_queue_url" {
  value = aws_sqs_queue.flask_queue.id
}
