variable "public_subnet_id" {
  description = "Public subnet ID where the NAT Gateway will be placed"
}

variable "private_route_table_id" {
  description = "Private route table ID to add the NAT Gateway route to"
}

# Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-gateway-eip"
  }
}

# NAT Gateway — sits in a public subnet, routes outbound traffic for private subnets
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_eip.nat]
}

# Route all outbound traffic from private subnets through the NAT Gateway
resource "aws_route" "private_nat" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}
