resource "aws_security_group" "jilani_sg" {
  name        = "jilani_sg"
  description = "Security group jilani"
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
    Name = "jilani_sg"
  }
}

resource "aws_subnet" "jilani_subnet" {
  vpc_id     = var.vpc_id
  cidr_block = "172.31.70.0/24"

  tags = {
    Name = "jilani_subnet"
  }
}

resource "aws_key_pair" "jilani_key" {
  key_name   = "jilani_key"
  public_key = file(pathexpand("~/.ssh/jilani_key.pub"))
}

resource "aws_instance" "jilani_serverweb" {
  ami                         = var.vm_image
  instance_type               = var.vm_instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.jilani_subnet.id
  vpc_security_group_ids      = [aws_security_group.jilani_sg.id]
  key_name                    = aws_key_pair.jilani_key.key_name

  tags = {
    Name = "jilani_serverweb"
  }
}
