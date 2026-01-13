# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "task-management-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "task-management-cluster"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "auth_service" {
  name              = "/ecs/auth-service"
  retention_in_days = 7

  tags = {
    Name    = "auth-service-logs"
    Service = "auth"
  }
}

resource "aws_cloudwatch_log_group" "task_service" {
  name              = "/ecs/task-service"
  retention_in_days = 7

  tags = {
    Name    = "task-service-logs"
    Service = "task"
  }
}

# Auth Service Task Definition
resource "aws_ecs_task_definition" "auth_service" {
  family                   = "auth-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "auth-service-container"
    image     = "${aws_ecr_repository.auth_service.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [{
      name  = "JWT_EXPIRATION"
      value = "3600"
    }]

    secrets = [
      {
        name      = "DB_HOST"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:host::"
      },
      {
        name      = "DB_NAME"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:dbname::"
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:password::"
      },
      {
        name      = "DB_PORT"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:port::"
      },
      {
        name      = "DB_USER"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:username::"
      },
      {
        name      = "JWT_SECRET"
        valueFrom = "${aws_secretsmanager_secret.jwt_secret.arn}:secret::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.auth_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/auth/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = {
    Name    = "auth-service-task"
    Service = "auth"
  }
}

# Task Service Task Definition
resource "aws_ecs_task_definition" "task_service" {
  family                   = "task-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "task-service"
    image     = "${aws_ecr_repository.task_service.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [{
      name  = "AUTH_SERVICE_URL"
      value = "http://auth-service.${aws_ecs_cluster.main.name}:3000"
    }]

    secrets = [
      {
        name      = "DB_HOST"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:host::"
      },
      {
        name      = "DB_NAME"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:dbname::"
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:password::"
      },
      {
        name      = "DB_PORT"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:port::"
      },
      {
        name      = "DB_USER"
        valueFrom = "${aws_secretsmanager_secret.rds_credentials.arn}:username::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.task_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/tasks/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = {
    Name    = "task-service-task"
    Service = "task"
  }
}

# Auth Service ECS Service
resource "aws_ecs_service" "auth_service" {
  name            = "auth-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth_service.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.auth_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth_service.arn
    container_name   = "auth-service-container"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.auth_service.arn
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener_rule.auth_service
  ]

  tags = {
    Name    = "auth-service"
    Service = "auth"
  }
}

# Task Service ECS Service
resource "aws_ecs_service" "task_service" {
  name            = "task-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.task_service.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.task_service.arn
    container_name   = "task-service"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener_rule.task_service
  ]

  tags = {
    Name    = "task-service"
    Service = "task"
  }
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = aws_ecs_cluster.main.name
  vpc  = var.vpc_id

  tags = {
    Name = "task-management-service-discovery"
  }
}

# Service Discovery Service for Auth
resource "aws_service_discovery_service" "auth_service" {
  name = "auth-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name    = "auth-service-discovery"
    Service = "auth"
  }
}
