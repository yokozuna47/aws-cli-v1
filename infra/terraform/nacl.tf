# NACL (stateless) appliquée au sous-réseau bastion/cible.
# Rappel : la NACL ne filtre que le trafic qui franchit la frontière du sous-réseau
# (admin <-> bastion via Internet). Le trafic bastion <-> cible, dans le même
# sous-réseau, n'est filtré que par les Security Groups (stateful).
resource "aws_network_acl" "musin_bastion_nacl" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.musin_bastion_subnet.id]

  tags = {
    Name = "musin_bastion_nacl"
  }
}

# Entrant : autoriser le SSH (22) depuis l'IP admin uniquement
resource "aws_network_acl_rule" "musin_nacl_in_ssh" {
  network_acl_id = aws_network_acl.musin_bastion_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.admin_ip}/32"
  from_port      = 22
  to_port        = 22
}

# Sortant : autoriser le trafic retour sur les ports éphémères (1024-65535)
resource "aws_network_acl_rule" "musin_nacl_out_ephemeral" {
  network_acl_id = aws_network_acl.musin_bastion_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
