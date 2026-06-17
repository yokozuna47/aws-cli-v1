variable "admin_ip" {
  type        = string
  description = "IP publique personnelle autorisée en SSH vers le bastion (sans le /32, ex: 203.0.113.42)"
}
