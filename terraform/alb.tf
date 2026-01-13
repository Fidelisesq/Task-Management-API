# Application Load Balancer
resource "aws_lb" "main" {
  name               = "task-management-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name = "task-management-alb"
  }
}

# Target Group for Auth Service
resource "aws_lb_target_group" "auth_service" {
  name        = "auth-service-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/auth/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "auth-service-tg"
    Service = "auth"
  }
}

# Target Group for Task Service
resource "aws_lb_target_group" "task_service" {
  name        = "task-service-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/tasks/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "task-service-tg"
    Service = "task"
  }
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Listener Rule for Auth Service
resource "aws_lb_listener_rule" "auth_service" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_service.arn
  }

  condition {
    path_pattern {
      values = ["/auth", "/auth/*"]
    }
  }

  tags = {
    Name    = "auth-service-rule"
    Service = "auth"
  }
}

# Listener Rule for Task Service
resource "aws_lb_listener_rule" "task_service" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.task_service.arn
  }

  condition {
    path_pattern {
      values = ["/tasks", "/tasks/*"]
    }
  }

  tags = {
    Name    = "task-service-rule"
    Service = "task"
  }
}
