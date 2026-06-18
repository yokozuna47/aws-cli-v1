resource "aws_lb" "public" {
  name               = "td-alb-public-28"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_public.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "web" {
  name     = "td-tg-web-28"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id
  health_check { path = "/health" }
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
  count                  = 1
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data = templatefile("${path.module}/web/user_data.sh.tpl", {
    internal_alb_dns = aws_lb.internal.dns_name
  })
  tags = { Name = "td-web-${count.index}" }
}

resource "aws_lb_target_group_attachment" "web" {
  count            = 1
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
