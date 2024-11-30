provider "aws" {
  region = "us-east-1" # Adjust as necessary
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "example-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "example-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                  = 3
  vpc_id                 = aws_vpc.this.id
  cidr_block             = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone      = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count                  = 3
  vpc_id                 = aws_vpc.this.id
  cidr_block             = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 3)
  availability_zone      = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "public-route-table"
  }
}

# Internet Access Route for Public Subnets
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.use_single_nat ? 1 : 3
  tags = {
    Name = "nat-eip-${count.index + 1}"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  count         = var.use_single_nat ? 1 : 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.use_single_nat ? 0 : count.index].id
  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = 3
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "private-route-table-${count.index + 1}"
  }
}

# Route Private Subnets through NAT Gateways
resource "aws_route" "private_nat" {
  count                  = 3
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.use_single_nat ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

# Associate Private Subnets with Private Route Tables
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data Source for Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}
