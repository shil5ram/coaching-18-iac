output "aws_role_arn_to_use_in_github" {
  value       = aws_iam_role.github_actions_role.arn
  description = "Copy this ARN value directly into your GitHub Actions workflow configuration"
}

