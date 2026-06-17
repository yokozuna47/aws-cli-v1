resource "aws_subnet" "public_a" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.80.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "td2-public-${var.student_id}" }
}

resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.igw.id
  }
  tags = { Name = "td2-public-${var.student_id}" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
