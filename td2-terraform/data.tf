data "aws_vpc" "default" {
  default = true
}

# Ce VPC partage n'a aucun subnet "default_for_az" -> on cible le /20 public en eu-west-3a
data "aws_subnet" "public_a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.aws_region}a"

  filter {
    name   = "cidr-block"
    values = ["172.31.192.0/20"]
  }
}
