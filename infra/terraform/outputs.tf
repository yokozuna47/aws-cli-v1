# --- Serveur web (main.tf) ---
output "instance_public_ip" {
  description = "IP publique de l'instance EC2"
  value       = aws_instance.musin_serverweb.public_ip
}

output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.musin_serverweb.id
}

output "subnet_id" {
  description = "ID du subnet"
  value       = aws_subnet.musin_subnet.id
}

output "security_group_id" {
  description = "ID du security group"
  value       = aws_security_group.musin_sg.id
}

# --- Bastion / Cible (bastion.tf) ---
output "bastion_public_ip" {
  description = "IP publique du bastion (point d'entrée SSH)"
  value       = aws_instance.musin_bastion.public_ip
}

output "cible_private_ip" {
  description = "IP privée de la cible (accessible uniquement via le bastion)"
  value       = aws_instance.musin_cible.private_ip
}

output "bastion_sg_id" {
  description = "ID du security group du bastion"
  value       = aws_security_group.musin_bastion_sg.id
}

output "cible_sg_id" {
  description = "ID du security group de la cible"
  value       = aws_security_group.musin_cible_sg.id
}

output "bastion_nacl_id" {
  description = "ID de la NACL associée au sous-réseau bastion/cible"
  value       = aws_network_acl.musin_bastion_nacl.id
}
