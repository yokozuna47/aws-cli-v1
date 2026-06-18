# Isolation logique des tiers par la chaine de Security Groups
# (le VPC par defaut n a que des subnets publics).
resource "aws_security_group" "alb_public" {
  name   = "td-sg-alb-public"
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
}

resource "aws_security_group" "web" {
  name   = "td-sg-web"
  vpc_id = data.aws_vpc.main.id
  ingress {
    description     = "HTTP depuis ALB public uniquement"
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
}

resource "aws_security_group" "alb_internal" {
  name   = "td-sg-alb-internal"
  vpc_id = data.aws_vpc.main.id
  ingress {
    description     = "HTTP depuis le tier web"
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
}

resource "aws_security_group" "app" {
  name   = "td-sg-app"
  vpc_id = data.aws_vpc.main.id
  ingress {
    description     = "HTTP depuis ALB interne"
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
}
