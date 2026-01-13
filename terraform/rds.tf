# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "task-mgmt-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "task-mgmt-db-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier     = "task-management-db"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "taskmanagement"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = true
  final_snapshot_identifier = "task-management-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "task-management-db"
  }
}
