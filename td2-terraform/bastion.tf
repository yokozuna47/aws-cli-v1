# AMI Ubuntu 22.04 (Canonical) - requise pour le script Suricata (apt)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

# SG bastion : SSH entrant depuis MON IP uniquement, tout sortant
resource "aws_security_group" "bastion" {
  name        = "td2-bastion-${var.student_id}"
  description = "SSH bastion (filtrage entrant)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH depuis mon IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "td2-bastion-${var.student_id}"
  }
}

# Instance bastion dans le subnet public, avec IP publique
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "td2-bastion-${var.student_id}"
  }
}

output "bastion_public_ip" {
  description = "IP publique du bastion"
  value       = aws_instance.bastion.public_ip
}
