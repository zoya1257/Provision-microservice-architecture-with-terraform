resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow browse EC2 to connect to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.browse_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDSSG"
  }
}

resource "aws_rds_cluster" "browse_cluster" {
  cluster_identifier     = "browse-cluster"
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned"
  master_username        = "zoya"
  master_password        = "StrongPassword123!" # You can use variables/secrets for this
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.browse_subnets.name
}

resource "aws_rds_cluster_instance" "browse_instances" {
  count               = 2
  identifier          = "browse-instance-${count.index}"
  cluster_identifier  = aws_rds_cluster.browse_cluster.id
  instance_class      = "db.t3.medium"
  engine              = "aurora-mysql"
  publicly_accessible = false
}

resource "aws_db_subnet_group" "browse_subnets" {
  name       = "browse-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "BrowseDBSubnetGroup"
  }
}

output "rds_endpoint" {
  value = aws_rds_cluster.browse_cluster.endpoint
}

