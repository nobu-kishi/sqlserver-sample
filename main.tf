variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
  default     = "vpc-033bd8d4a91ab522f"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
  default     = ["subnet-0da4d133d06d990e4", "subnet-0e20d6db4b1d027af", ]
}

variable "sqlserver_config" {
  description = "SQL Server configuration parameters"
  type = object({
    identifier     = string
    engine         = string
    engine_version = string
    instance_class = string
    deletion_protection = optional(bool, false)
  })
  default = {
    identifier     = "sqlserver-db"
    engine         = "sqlserver-ex" # "sqlserver-se"
    engine_version = "16.00.4175.1.v1"
    instance_class = "db.t3.micro" # "db.m5.large"
    # deletion_protection = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

data "aws_kms_key" "secretsmanager" {
  key_id = "alias/aws/secretsmanager" # または別の指定されたキーがあれば適宜変更
}

data "aws_kms_key" "performance" {
  key_id = "alias/aws/rds" # または別の指定されたキーがあれば適宜変更
}



resource "aws_db_instance" "sqlserver" {
  identifier                    = var.sqlserver_config.identifier
  engine                        = var.sqlserver_config.engine
  engine_version                = var.sqlserver_config.engine_version
  instance_class                = var.sqlserver_config.instance_class
  username                      = "sa" # SQL Severのデフォルト管理者ユーザー
  manage_master_user_password   = true
  master_user_secret_kms_key_id = data.aws_kms_key.secretsmanager.arn
  parameter_group_name          = "default.sqlserver-ex-16.0"
  # parameter_group_name            = "default.sqlserver-se-16.0"
  skip_final_snapshot             = true
  publicly_accessible             = false
  multi_az                        = false # true
  iops                            = 3000
  storage_type                    = "io2"
  performance_insights_enabled    = true
  performance_insights_kms_key_id = data.aws_kms_key.performance.arn
  enabled_cloudwatch_logs_exports = ["agent", "error"]
  allocated_storage               = 20 # ストレージサイズ（GB）
  max_allocated_storage           = 1000
  copy_tags_to_snapshot           = true
  ca_cert_identifier              = "rds-ca-rsa2048-g1"
  deletion_protection             = var.sqlserver_config.deletion_protection 
  license_model                   = "license-included"
  character_set_name              = "SQL_Latin1_General_CP1_CI_AS"
  network_type                    = "IPV4"
  monitoring_interval             = 0
  vpc_security_group_ids = [ aws_security_group.db_sg.id ]
}

resource "aws_security_group" "db_sg" {
  name        = "sqlserver-db-sg"
  description = "Security group for SQL Server RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # 適宜修正
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "sqlserver-subnet-group"
  subnet_ids = var.subnet_ids
}