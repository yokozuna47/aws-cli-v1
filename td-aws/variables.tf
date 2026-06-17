variable "aws_region" {
  default = "eu-west-3"
}

variable "azs" {
  type    = list(string)
  default = ["eu-west-3a", "eu-west-3b"]
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# 4 paires de subnets (public, web, app, data) sur 2 AZ = 8 sous-reseaux
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}
variable "web_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}
variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.20.0/24", "10.0.21.0/24"]
}
variable "data_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.30.0/24", "10.0.31.0/24"]
}

variable "db_username" {
  default = "appuser"
}

variable "db_password" {
  description = "Mot de passe RDS - via TF_VAR_db_password, jamais en clair"
  type        = string
  sensitive   = true
}

variable "db_name" {
  default = "signupdb"
}
