# NACL stateless appliquée au sous-réseau bastion/cible.
# Rappel : la NACL filtre uniquement le trafic qui franchit
# la frontière du subnet. Le trafic bastion <-> cible dans
# le même subnet est géré par les Security Groups (stateful).
resource "aws_network_acl" "musin_bastion_nacl" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.musin_bastion_subnet.id]

  tags = {
    Name = "musin_bastion_nacl"
  }
}

# Entrant : SSH (22) depuis l'IP admin uniquement
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

# Entrant : bloquer tout le reste
resource "aws_network_acl_rule" "musin_nacl_in_deny_all" {
  network_acl_id = aws_network_acl.musin_bastion_nacl.id
  rule_number    = 32766
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# Sortant : ports éphémères (réponses TCP vers l'admin)
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

# Sortant : SSH du bastion vers la cible (172.31.43.0/24)
resource "aws_network_acl_rule" "musin_nacl_out_ssh_cible" {
  network_acl_id = aws_network_acl.musin_bastion_nacl.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "172.31.43.0/24"
  from_port      = 22
  to_port        = 22
}
