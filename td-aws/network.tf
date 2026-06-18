# VPC par défaut et IGW existants (lecture seule)
data "aws_vpc" "main" {
  default = true
}

data "aws_internet_gateway" "igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

# --- Subnets PUBLICS ---
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.public_cidrs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "td-public-${count.index}" }
}

# --- Subnets PRIVÉS web ---
resource "aws_subnet" "web" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.web_cidrs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "td-web-${count.index}" }
}

# --- Subnets PRIVÉS app ---
resource "aws_subnet" "app" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.app_cidrs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "td-app-${count.index}" }
}

# --- Subnets PRIVÉS data ---
resource "aws_subnet" "data" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.data_cidrs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "td-data-${count.index}" }
}

# --- NAT Gateway par AZ ---
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
  tags   = { Name = "td-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "td-nat-${count.index}" }
}

# --- Route table publique ---
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.igw.id
  }
  tags = { Name = "td-rtb-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Route tables privées (une par AZ) ---
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = data.aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = { Name = "td-rtb-private-${count.index}" }
}

resource "aws_route_table_association" "web" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "data" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
