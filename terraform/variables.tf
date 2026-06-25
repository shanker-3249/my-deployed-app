variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "my-node-app"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair for SSH access"
  type        = string
  # Set this in terraform.tfvars or via -var flag
}

variable "github_repo" {
  description = "HTTPS URL of your GitHub repository"
  type        = string
  default     = "https://github.com/YOUR_USERNAME/YOUR_REPO.git"
}

variable "environment" {
  description = "Environment tag (dev / staging / prod)"
  type        = string
  default     = "dev"
}
