# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "task-mgmt-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-mgmt-alb-sg"
  }
}

# Auth Service Security Group
resource "aws_security_group" "auth_service" {
  name        = "task-mgmt-auth-sg"
  description = "Security group for Auth Service"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-mgmt-auth-sg"
  }
}

# Task Service Security Group
resource "aws_security_group" "task_service" {
  name        = "task-mgmt-task-sg"
  description = "Security group for Task Service"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-mgmt-task-sg"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "task-mgmt-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from Auth Service"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.auth_service.id]
  }

  ingress {
    description     = "PostgreSQL from Task Service"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.task_service.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-mgmt-rds-sg"
  }
}

# VPC Endpoint Security Group
resource "aws_security_group" "vpc_endpoints" {
  name        = "task-mgmt-vpc-endpoint-sg"
  description = "Security group for VPC Endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from Auth Service"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.auth_service.id]
  }

  ingress {
    description     = "HTTPS from Task Service"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.task_service.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-mgmt-vpc-endpoint-sg"
  }
}
