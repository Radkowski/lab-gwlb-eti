data "aws_availability_zones" "AZs" {
  state = "available"
}



variable "DeploymentName" {}
variable "VPC_CIDR" {}
variable "IPv6_ENABLED" {}
variable "APPLIANCE_VPC" {}



resource "aws_vpc" "RadLabVPC" {
  cidr_block                       = var.VPC_CIDR
  instance_tenancy                 = "default"
  enable_dns_hostnames             = "true"
  assign_generated_ipv6_cidr_block = var.IPv6_ENABLED ? true : false
  tags = {
    Name = var.DeploymentName
  }
}


resource "aws_subnet" "Pub-Subnet" {
  count                           = 2
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index)
  ipv6_cidr_block                 = var.IPv6_ENABLED ? cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index) : null
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % 2]
  assign_ipv6_address_on_creation = var.IPv6_ENABLED ? true : false
  map_public_ip_on_launch         = true
  tags = {
    Name = join("", [var.DeploymentName, "-Pub"])
  }
}


resource "aws_subnet" "Pub-Appliance-Subnet" {
  count                           = var.APPLIANCE_VPC ? 2 : 0
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index + 2)
  ipv6_cidr_block                 = var.IPv6_ENABLED ? cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index + 2) : null
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % 2]
  assign_ipv6_address_on_creation = var.IPv6_ENABLED ? true : false
  map_public_ip_on_launch         = true
  tags = {
    Name = join("", [var.DeploymentName, "-Pub-Apliance"])
  }
}


resource "aws_subnet" "Priv-Subnet" {
  count                           = 2
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index + 4)
  ipv6_cidr_block                 = var.IPv6_ENABLED ? cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index + 4) : null
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % 2]
  assign_ipv6_address_on_creation = var.IPv6_ENABLED ? true : false
  map_public_ip_on_launch         = false
  tags = {
    Name = join("", [var.DeploymentName, "-Priv"])
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-IGW"])
  }
}


resource "aws_eip" "natgw_ip" {
  count      = 2
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = join("", [var.DeploymentName, "-NATGW-IP-", count.index])
  }
}


resource "aws_nat_gateway" "natgw" {
  count         = 2
  allocation_id = aws_eip.natgw_ip[count.index].id
  subnet_id     = aws_subnet.Pub-Subnet[count.index].id
  depends_on    = [aws_internet_gateway.igw, aws_eip.natgw_ip]
  tags = {
    Name = join("", [var.DeploymentName, "-NATGW-", count.index])
  }
}


resource "aws_egress_only_internet_gateway" "egw" {
  count  = var.IPv6_ENABLED ? 1 : 0
  vpc_id = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-EIGW"])
  }
}


resource "aws_route_table" "Pub-Route" {
  depends_on = [aws_vpc.RadLabVPC, aws_internet_gateway.igw]
  vpc_id     = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-Pub"])
  }
}


resource "aws_route_table" "Pub-Appliance-Route" {
  depends_on = [aws_vpc.RadLabVPC, aws_internet_gateway.igw]
  count      = var.APPLIANCE_VPC ? 1 : 0
  vpc_id     = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-Pub-Appliance"])
  }
}


resource "aws_route_table" "Priv-Route" {
  count      = 2
  depends_on = [aws_vpc.RadLabVPC, aws_internet_gateway.igw]
  vpc_id     = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-Priv-", count.index])
  }
}


resource "aws_route" "Pub" {
  depends_on             = [aws_route_table.Pub-Route]
  route_table_id         = aws_route_table.Pub-Route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


resource "aws_route" "Pub-v6" {
  depends_on                  = [aws_route_table.Pub-Route]
  count                       = var.IPv6_ENABLED ? 1 : 0
  route_table_id              = aws_route_table.Pub-Route.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
}


resource "aws_route" "Pub-Appliance" {
  depends_on             = [aws_route_table.Pub-Appliance-Route]
  count                  = var.APPLIANCE_VPC ? 1 : 0
  route_table_id         = aws_route_table.Pub-Appliance-Route[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


resource "aws_route" "Pub-Appliance-v6" {
  depends_on                  = [aws_route_table.Pub-Appliance-Route]
  count                       = var.IPv6_ENABLED && var.APPLIANCE_VPC ? 1 : 0
  route_table_id              = aws_route_table.Pub-Appliance-Route[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
}


resource "aws_route" "Priv" {
  count = 2
  timeouts {
    create = "5m"
  }
  depends_on             = [aws_route_table.Priv-Route, aws_nat_gateway.natgw]
  route_table_id         = aws_route_table.Priv-Route[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw[count.index].id
}


resource "aws_route" "Priv-Route-v6" {
  count = var.IPv6_ENABLED && var.APPLIANCE_VPC ? 2 : 0
  timeouts {
    create = "5m"
  }
  depends_on                  = [aws_route_table.Priv-Route, aws_egress_only_internet_gateway.egw]
  route_table_id              = aws_route_table.Priv-Route[count.index].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.egw[0].id
}


resource "aws_route_table_association" "PubAssociation" {
  count          = 2
  subnet_id      = aws_subnet.Pub-Subnet[count.index].id
  route_table_id = aws_route_table.Pub-Route.id
}


resource "aws_route_table_association" "PubApplianceAssociation" {
  count          = var.APPLIANCE_VPC ? 2 : 0
  subnet_id      = aws_subnet.Pub-Appliance-Subnet[count.index].id
  route_table_id = aws_route_table.Pub-Appliance-Route[0].id
}


resource "aws_route_table_association" "PrivAssociation" {
  count          = 2
  subnet_id      = aws_subnet.Priv-Subnet[count.index].id
  route_table_id = aws_route_table.Priv-Route[count.index].id
}



output "VPCID" {
  value = aws_vpc.RadLabVPC.id
}


output "PRIVSUBNETSID" {
  value = aws_subnet.Priv-Subnet[*].id
}


output "ROUTES" {
  value = var.APPLIANCE_VPC ? [aws_route_table.Priv-Route[0].id, aws_route_table.Priv-Route[1].id, aws_route_table.Pub-Route.id, aws_route_table.Pub-Appliance-Route[0].id] : [aws_route_table.Priv-Route[0].id, aws_route_table.Priv-Route[1].id, aws_route_table.Pub-Route.id]
}
