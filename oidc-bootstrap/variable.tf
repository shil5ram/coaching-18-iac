variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "github_org_or_username" {
  type        = string
  description = "Your personal GitHub username or Organization name"

}

variable "github_repository1_name" {
  type        = string
  description = "The name of the first GitHub repository you want to grant access to"
}

variable "github_repository2_name" {
  type        = string
  description = "The name of the second GitHub repository you want to grant access to"
}
