output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = "https://${var.api_subdomain}.${var.domain_name}"
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "https://${var.frontend_subdomain}.${var.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for frontend"
  value       = aws_s3_bucket.frontend.id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "ecr_auth_repository_url" {
  description = "ECR repository URL for auth service"
  value       = aws_ecr_repository.auth_service.repository_url
}

output "ecr_task_repository_url" {
  description = "ECR repository URL for task service"
  value       = aws_ecr_repository.task_service.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "auth_service_name" {
  description = "Auth service name"
  value       = aws_ecs_service.auth_service.name
}

output "task_service_name" {
  description = "Task service name"
  value       = aws_ecs_service.task_service.name
}
