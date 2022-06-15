variable "DeploymentName" {}
variable "LEFTVPC" {}
variable "LEFTSUBNETS" {}
variable "RIGHTVPC" {}
variable "RIGHTSUBNETS" {}
variable "VPCNAMES" {}
variable "LEFTROUTES" {}
variable "RIGHTROUTES" {}
variable "LEFTCIDR" {}
variable "RIGHTCIDR" {}



locals {
  vpcids   = [var.LEFTVPC, var.RIGHTVPC]
  subnets  = [var.LEFTSUBNETS, var.RIGHTSUBNETS]
  vpcnames = var.VPCNAMES
}



resource "aws_ec2_transit_gateway" "LocalTGW" {
  description                    = "LocalTGW"
  auto_accept_shared_attachments = "enable"
  tags = {
    Name = join("", [var.DeploymentName, "-LocalTGW"])
  }
}


resource "aws_ec2_transit_gateway_vpc_attachment" "VPC-attach" {
  count              = 2
  transit_gateway_id = aws_ec2_transit_gateway.LocalTGW.id
  subnet_ids         = local.subnets[count.index]
  vpc_id             = local.vpcids[count.index]
  tags = {
    Name = join("", [var.DeploymentName, "-attach-to-", local.vpcnames[count.index + 2]])
  }
}


resource "aws_route" "VPC-C-via-attach" {
  count = 3
  timeouts {
    create = "5m"
  }
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.VPC-attach]
  route_table_id         = var.LEFTROUTES[count.index]
  destination_cidr_block = var.RIGHTCIDR
  transit_gateway_id     = aws_ec2_transit_gateway.LocalTGW.id
}


resource "aws_route" "VPC-App-via-attach" {
  count = 4
  timeouts {
    create = "5m"
  }
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.VPC-attach]
  route_table_id         = var.RIGHTROUTES[count.index]
  destination_cidr_block = var.LEFTCIDR
  transit_gateway_id     = aws_ec2_transit_gateway.LocalTGW.id
}
