variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "task-management-api"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "taskmanagement"
}

variable "vpc_id" {
  description = "VPC ID for the infrastructure"
  type        = string
  default     = "vpc-0792f2f110cb731ed"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
  default     = ["subnet-01578e4938893297d", "subnet-0bbad45200c46c4e5"]
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
  default     = []  # Will be fetched via data source if empty
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "fozdigitalz.com"
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
  default     = "Z053615514X9UZZVP030H"
}

variable "api_subdomain" {
  description = "API subdomain"
  type        = string
  default     = "api"
}

variable "frontend_subdomain" {
  description = "Frontend subdomain"
  type        = string
  default     = "task-management"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = "arn:aws:acm:us-east-1:211125602758:certificate/697cf89b-9931-435f-a5f0-c8fd98a6ecdc"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  sensitive   = true
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks"
  type        = string
  default     = "512"
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}
