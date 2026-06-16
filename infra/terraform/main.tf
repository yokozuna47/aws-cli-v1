resource "aws_security_group" "musin_sg" {
  name        = "musin_sg"
  description = "Security group musin"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "musin_sg"
  }
}

resource "aws_subnet" "musin_subnet" {
  vpc_id     = var.vpc_id
  cidr_block = "172.31.42.0/24"

  tags = {
    Name = "musin_subnet"
  }
}

resource "aws_key_pair" "musin_key" {
  key_name   = "musin_key"
  public_key = file(pathexpand("~/.ssh/musin_key.pub"))
}

resource "aws_instance" "musin_serverweb" {
  ami                         = var.vm_image
  instance_type               = var.vm_instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.musin_subnet.id
  vpc_security_group_ids      = [aws_security_group.musin_sg.id]
  key_name                    = aws_key_pair.musin_key.key_name

  tags = {
    Name = "musin_serverweb"
  }
}
