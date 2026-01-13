# ECR Repository for Auth Service
resource "aws_ecr_repository" "auth_service" {
  name                 = "auth-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "auth-service"
    Service = "auth"
  }
}

# ECR Lifecycle Policy for Auth Service
resource "aws_ecr_lifecycle_policy" "auth_service" {
  repository = aws_ecr_repository.auth_service.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ECR Repository for Task Service
resource "aws_ecr_repository" "task_service" {
  name                 = "task-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "task-service"
    Service = "task"
  }
}

# ECR Lifecycle Policy for Task Service
resource "aws_ecr_lifecycle_policy" "task_service" {
  repository = aws_ecr_repository.task_service.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
