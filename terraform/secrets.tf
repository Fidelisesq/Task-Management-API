# Secrets Manager for sensitive data

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.project_name}-rds-credentials"
  description             = "RDS database credentials for Task Management API"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-rds-credentials"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}-jwt-secret"
  description             = "JWT signing secret for Task Management API"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-jwt-secret"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    secret = var.jwt_secret
  })
}
