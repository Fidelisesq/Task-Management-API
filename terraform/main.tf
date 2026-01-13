terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    bucket         = "foz-terraform-state-bucket"
    key            = "task-management-api/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TaskManagementAPI"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source to fetch public subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Use provided subnet IDs or fetch from data source
locals {
  public_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.aws_subnets.public.ids
}
