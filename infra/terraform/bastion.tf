# Sous-réseau dédié bastion + cible
# CIDR distinct du subnet principal (172.31.42.0/24)
resource "aws_subnet" "musin_bastion_subnet" {
  vpc_id     = var.vpc_id
  cidr_block = "172.31.43.0/24"

  tags = {
    Name = "musin_bastion_subnet"
  }
}

# SG bastion : SSH autorisé uniquement depuis l'IP admin
resource "aws_security_group" "musin_bastion_sg" {
  name        = "musin_bastion_sg"
  description = "Bastion - SSH depuis l'IP admin uniquement"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["82.96.161.255/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "musin_bastion_sg"
  }
}

# SG cible : SSH + ICMP autorisés uniquement depuis le SG bastion
resource "aws_security_group" "musin_cible_sg" {
  name        = "musin_cible_sg"
  description = "Cible - SSH et ICMP depuis le bastion uniquement"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.musin_bastion_sg.id]
  }

  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.musin_bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "musin_cible_sg"
  }
}

# Instance bastion : IP publique, point d'entrée unique
# Utilise aws_key_pair.musin_key défini dans main.tf
resource "aws_instance" "musin_bastion" {
  ami                         = var.vm_image
  instance_type               = var.vm_instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.musin_bastion_subnet.id
  vpc_security_group_ids      = [aws_security_group.musin_bastion_sg.id]
  key_name                    = aws_key_pair.musin_key.key_name

  tags = {
    Name = "musin_bastion"
  }
}

# Instance cible : pas d'IP publique, accessible via le bastion seulement
resource "aws_instance" "musin_cible" {
  ami                         = var.vm_image
  instance_type               = var.vm_instance_type
  associate_public_ip_address = false
  subnet_id                   = aws_subnet.musin_bastion_subnet.id
  vpc_security_group_ids      = [aws_security_group.musin_cible_sg.id]
  key_name                    = aws_key_pair.musin_key.key_name

  tags = {
    Name = "musin_cible"
  }
}
