resource "aws_db_subnet_group" "data" {
  name       = "td-db-subnet-group"
  subnet_ids = aws_subnet.data[*].id
  tags       = { Name = "td-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier             = "td-postgres"
  engine                 = "postgres"
  engine_version         = "16" # verifier : aws rds describe-db-engine-versions --engine postgres
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.data.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = true
  publicly_accessible = false
  skip_final_snapshot = true
}
