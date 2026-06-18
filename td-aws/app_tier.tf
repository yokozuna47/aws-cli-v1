resource "aws_lb" "internal" {
  name               = "td-alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_internal.id]
  subnets            = aws_subnet.app[*].id
  tags               = { Name = "td-alb-internal" }
}

resource "aws_lb_target_group" "app" {
  name     = "td-tg-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id
  health_check { path = "/health" }
  tags = { Name = "td-tg-app" }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_instance" "app" {
  count                  = length(var.azs)
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.app[count.index].id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/app/user_data.sh.tpl", {
    db_host     = aws_db_instance.postgres.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
  })

  tags = { Name = "td-app-${count.index}" }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = length(var.azs)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}
