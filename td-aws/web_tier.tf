resource "aws_lb" "public" {
  name               = "td-alb-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_public.id]
  subnets            = aws_subnet.public[*].id
  tags               = { Name = "td-alb-public" }
}

resource "aws_lb_target_group" "web" {
  name     = "td-tg-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id
  health_check { path = "/health" }
  tags = { Name = "td-tg-web" }
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_instance" "web" {
  count                  = length(var.azs)
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.web[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/web/user_data.sh.tpl", {
    internal_alb_dns = aws_lb.internal.dns_name
  })

  tags = { Name = "td-web-${count.index}" }
}

resource "aws_lb_target_group_attachment" "web" {
  count            = length(var.azs)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
