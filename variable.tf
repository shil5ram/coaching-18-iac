variable "aws_region" {
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  default     = "production"
}

variable "github_org_or_username" {
  type        = string
  description = "Your personal GitHub username or Organization name"
  default     = "your-github-username" 
}
