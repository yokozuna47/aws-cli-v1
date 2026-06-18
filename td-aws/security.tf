resource "aws_security_group" "alb_public" {
  name   = "td-alb-public"
  vpc_id = data.aws_vpc.main.id

  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-alb-public" }
}

resource "aws_security_group" "web" {
  name   = "td-web"
  vpc_id = data.aws_vpc.main.id

  ingress {
    description     = "HTTP depuis l'ALB public uniquement"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-web" }
}

resource "aws_security_group" "alb_internal" {
  name   = "td-alb-internal"
  vpc_id = data.aws_vpc.main.id

  ingress {
    description     = "HTTP depuis le tier web uniquement"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-alb-internal" }
}

resource "aws_security_group" "app" {
  name   = "td-app"
  vpc_id = data.aws_vpc.main.id

  ingress {
    description     = "HTTP depuis l'ALB interne uniquement"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-app" }
}

resource "aws_security_group" "rds" {
  name   = "td-rds"
  vpc_id = data.aws_vpc.main.id

  ingress {
    description     = "PostgreSQL depuis le tier app uniquement"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-rds" }
}
