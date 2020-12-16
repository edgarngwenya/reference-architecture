resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = "VPC for ${var.environment_name}"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidr_blocks)
  vpc_id = aws_vpc.vpc.id
  cidr_block = element(var.public_subnet_cidr_blocks,count.index)
  availability_zone = element(var.availability_zones,count.index)
  tags = {
    Name = "Public Subnet for ${element(var.availability_zones,count.index)} in ${var.environment_name}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidr_blocks)
  vpc_id = aws_vpc.vpc.id
  cidr_block = element(var.private_subnet_cidr_blocks,count.index)
  availability_zone = element(var.availability_zones,count.index)
  tags = {
    Name = "Private Subnet for ${element(var.availability_zones,count.index)} in ${var.environment_name}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Internet Gateway for ${var.environment_name}"
  }
}

# Elastic IP
resource "aws_eip" "elastic_ip" {
  vpc      = true
  tags = {
    Name = "Elastic IP for NAT in ${var.environment_name}"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id = aws_subnet.public_subnets[0].id
  tags = {
    Name = "Nat Gateway for ${var.environment_name}"
  }
}

# Public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "Public Route Table for ${var.environment_name}"
  }
}

# Public route table association
resource "aws_route_table_association" "public_route_table_association" {
  count = length(var.public_subnet_cidr_blocks)
  subnet_id      = element(aws_subnet.public_subnets.*.id,count.index)
  route_table_id = aws_route_table.public_route_table.id
}

# Private route table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "Private Route Table for ${var.environment_name}"
  }
}

# Private route table association
resource "aws_route_table_association" "private_route_table_association" {
  count = length(var.private_subnet_cidr_blocks)
  subnet_id      = element(aws_subnet.private_subnets.*.id,count.index)
  route_table_id = aws_route_table.private_route_table.id
}
