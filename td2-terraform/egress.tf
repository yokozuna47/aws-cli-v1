# Sous-reseau prive (aucune IP publique)
resource "aws_subnet" "private" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.${100 + var.student_id}.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  tags = { Name = "td2-prive-${var.student_id}" }
}

# Elastic IP pour la NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "td2-nat-${var.student_id}" }
}

# NAT Gateway dans le subnet PUBLIC (elle a besoin de l'IGW)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "td2-nat-${var.student_id}" }
}

# Route table privee : tout le sortant passe par la NAT
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "td2-prive-${var.student_id}" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# SG instance privee : SSH uniquement depuis le bastion, tout sortant
resource "aws_security_group" "private" {
  name        = "td2-prive-${var.student_id}"
  description = "SSH depuis bastion, sortie via NAT"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "SSH depuis le bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    description = "Tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "td2-prive-${var.student_id}" }
}

# Instance privee : pas d'IP publique
resource "aws_instance" "private" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = var.key_name
  tags                   = { Name = "td2-prive-${var.student_id}" }
}

output "private_ip" {
  description = "IP privee de l'instance privee"
  value       = aws_instance.private.private_ip
}
