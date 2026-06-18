variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "eu-west-3"
}

variable "student_id" {
  description = "Numero d'etudiant (0-99) -> noms et CIDR uniques"
  type        = number
  default     = 28
}

variable "key_name" {
  description = "Nom de la paire de cles EC2 existante"
  type        = string
  default     = "cle-td2-aicha"
}

variable "my_ip" {
  description = "Ton IP publique en /32 pour le SSH"
  type        = string
  default     = "82.96.161.255/32"
}
