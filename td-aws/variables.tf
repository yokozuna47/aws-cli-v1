variable "aws_region" {
  default = "eu-west-3"
}

# VPC partage (par defaut) qui heberge le RDS
variable "vpc_id" {
  default = "vpc-0ebcdb39f7a526ef9"
}

# 2 subnets PUBLICS dans 2 AZ differentes (requis pour les ALB).
# Reutilisation des subnets du TD td-ipssi-rds-v2 (publics, AZ a + b).
variable "subnet_ids" {
  type    = list(string)
  default = ["subnet-08f42a14946d985b3", "subnet-0b9badcfeee357873"]
}

# --- RDS PARTAGE (fourni par l'enseignant) ---
variable "db_host" {
  default = "td-ipssi-rds-v2.clqqieekmedc.eu-west-3.rds.amazonaws.com"
}
variable "db_name" {
  default = "mydb"
}
variable "db_username" {
  default = "adminipssidb"
}
variable "db_schema" {
  description = "Mon schema PostgreSQL pour m'isoler des autres etudiants"
  default     = "yokozuna47"
}
variable "db_password" {
  description = "Mot de passe RDS partage - via TF_VAR_db_password"
  type        = string
  sensitive   = true
}
