resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "td-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "td-igw" }
}

# --- Subnets PUBLICS ---
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "td-public-${count.index}" }
}

# --- Subnets PRIVES web / app / data ---
resource "aws_subnet" "web" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.web_subnet_cidrs[count.index]
  tags              = { Name = "td-web-${count.index}" }
}

resource "aws_subnet" "app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.app_subnet_cidrs[count.index]
  tags              = { Name = "td-app-${count.index}" }
}

resource "aws_subnet" "data" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.data_subnet_cidrs[count.index]
  tags              = { Name = "td-data-${count.index}" }
}

# --- NAT Gateway (une par AZ) ---
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "td-nat-${count.index}" }
  depends_on    = [aws_internet_gateway.igw]
}

# --- Route table PUBLIQUE ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "td-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Route tables PRIVEES (une par AZ -> NAT de la meme AZ) ---
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = { Name = "td-private-rt-${count.index}" }
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
