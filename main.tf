terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket = "sctp-tfstate-ce13"
    key    = "shil-ce18/flaskapp-ecs-cluster/terraform.tfstate"
    region = "us-east-1"
    }
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
# 2. FLASKAPP S3 INFRASTRUCTURE RESOURCE
# ==========================================

resource "aws_s3_bucket" "flask_bucket" {
  bucket        = "${var.environment}-flaskapp-s3-bucket-2026"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "flask_bucket_privacy" {
  bucket = aws_s3_bucket.flask_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==========================================
# 3. FLASKAPP SQS INFRASTRUCTURE RESOURCE
# ==========================================

resource "aws_sqs_queue" "flask_queue" {
  name                      = "${var.environment}-flaskapp-sqs-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10

  tags = {
    Name        = "${var.environment}-flaskapp-sqs"
    Environment = var.environment
  }
}

# ==========================================
# 1. CREATE CLOUDWATCH LOG GROUP FOR ECS LOGS
# ==========================================
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.environment}-flask-apps"
  retention_in_days = 7 # Automatically purges old logs to save costs
}


# ==========================================
# 4. ECS CLUSTER & SERVICES VIA PUBLIC MODULE
# ==========================================

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = "${var.environment}-flask-apps-cluster"

  # Allocate shared resources to run Fargate containers dynamically
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  # The "services" map manages both apps globally under one definition block
  services = {

    # ----------------------------------------
    # Service 1: FlaskApp-S3
    # ----------------------------------------
    "flaskapp-s3" = {
      cpu    = 256
      memory = 512

      # Container Definition Layout
      container_definitions = {
        "s3-app-container" = {
          cpu       = 256
          memory    = 512
          essential = true
          image     = "255945442255.dkr.ecr.us-east-1.amazonaws.com/coaching-18-flask-private-repository:flask2s3-698a8f0cedc2104ed12d958621b0fe5a0af0c498" # Replaced dynamically via app pipeline

          port_mappings = [
            {
              name          = "s3-port"
              containerPort = 8080
              hostPort      = 8080
              protocol      = "tcp"
            }
          ]

          log_configuration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "flaskapp-s3"
            }
          }

          # Pass the variables provisioned directly above in main.tf
          environment = [
            {
              name  = "BUCKET_NAME"
              value = "${var.environment}-flaskapp-s3-bucket-2026"
            },
            {
              name  = "ENVIRONMENT"
              value = var.environment
            }
          ]
        }
      }

      # Networking Profiles
      subnet_ids       = ["subnet-00b4c98869b996d86", "subnet-07fe08d5909e677db"] # Replace with your real VPC Subnets
      assign_public_ip = true

      # FIXED: Define the security group rules natively for this service
      security_group_rules = {
        # Allow inbound traffic to the Flask app port
        ingress_8080 = {
          type        = "ingress"
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"] # Change this to restrict traffic if needed
        }
        # CRITICAL FIX: Allow all outbound traffic so it can pull the image from ECR
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }

    # ----------------------------------------
    # Service 2: FlaskApp-SQS
    # ----------------------------------------
    "flaskapp-sqs" = {
      cpu    = 256
      memory = 512

      container_definitions = {
        "sqs-app-container" = {
          cpu       = 256
          memory    = 512
          essential = true
          image     = "255945442255.dkr.ecr.us-east-1.amazonaws.com/coaching-18-flask-private-repository:flask2sqs-latest" # Replaced dynamically via app pipeline

          port_mappings = [
            {
              name          = "sqs-port"
              containerPort = 8080
              hostPort      = 8080
              protocol      = "tcp"
            }
          ]
          log_configuration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "flaskapp-sqs"
            }
          }
          environment = [
            {
              name  = "QUEUE_URL"
              value = "https://sqs.${var.aws_region}://{data.aws_caller_identity.current.account_id}/${var.environment}-flaskapp-sqs-queue"
            },
            {
              name  = "ENVIRONMENT"
              value = var.environment
            }
          ]
        }
      }

      subnet_ids       = ["subnet-00b4c98869b996d86", "subnet-07fe08d5909e677db"] # Replace with your real VPC Subnets
      assign_public_ip = true

      # FIXED: Define the security group rules natively for this service
      security_group_rules = {
        # Allow inbound traffic to the Flask app port
        ingress_8080 = {
          type        = "ingress"
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"] # Change this to restrict traffic if needed
        }
        # CRITICAL FIX: Allow all outbound traffic so it can pull the image from ECR
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = "flask-microservices"
  }
}

# Added data source to dynamically discover your AWS account ID for the SQS URL path
data "aws_caller_identity" "current" {}