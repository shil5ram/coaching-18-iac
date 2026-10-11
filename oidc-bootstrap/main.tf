terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
# 1. OIDC BOOTSTRAP LAYER (GITHUB TRUST)
# ==========================================

# Establish trust with GitHub's secure token authority
# resource "aws_iam_openid_connect_provider" "github" {
#   url             = "https://githubusercontent.com"
#   client_id_list  = ["://amazonaws.com"]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC Thumbprint
# }

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Security rule scoping access down to your specific GitHub account & repositories
data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org_or_username}*/${var.github_repository1_name}*:*",
        "repo:${var.github_org_or_username}*/${var.github_repository2_name}*:*"
      ]
    }
  }
}

#"principalId": "arn:aws:iam::255945442255:oidc-provider/token.actions.githubusercontent.com:sts.amazonaws.com:repo:shil5ram@287830560/coaching-18-app@1411771572:ref:refs/heads/main",
#       "userName": "repo:shil5ram@287830560/coaching-18-app@1411771572:ref:refs/heads/main",

# Deployment Role assumed by your pipelines
resource "aws_iam_role" "github_actions_role" {
  name               = "${var.environment}-github-actions-deployment-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json
}

# Attach administrative capability to provision infrastructure resources
resource "aws_iam_role_policy_attachment" "github_actions_poweruser" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}




