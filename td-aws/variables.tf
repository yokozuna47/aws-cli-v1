variable "aws_region" {
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_cidrs" {
  type    = list(string)
  default = ["172.31.0.0/24", "172.31.1.0/24"]
}

variable "web_cidrs" {
  type    = list(string)
  default = ["172.31.10.0/24", "172.31.11.0/24"]
}

variable "app_cidrs" {
  type    = list(string)
  default = ["172.31.20.0/24", "172.31.21.0/24"]
}

variable "data_cidrs" {
  type    = list(string)
  default = ["172.31.30.0/24", "172.31.31.0/24"]
}

variable "db_username" {
  default = "appuser"
}

variable "db_password" {
  description = "Mot de passe RDS — à passer via TF_VAR_db_password, jamais en clair dans le code"
  type        = string
  sensitive   = true
}

variable "db_name" {
  default = "signupdb"
}

variable "key_name" {
  description = "Nom de la paire de clés EC2 existante (pour dépannage SSH)"
  type        = string
  default     = "cle-td-jilani"
}
