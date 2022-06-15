variable "DeploymentName" {}
variable "VPCID" {}
variable "GWLBESUBNETSID" {}



resource "aws_lb_target_group" "target-group" {
  name                 = join("", [var.DeploymentName, "-target-group"])
  port                 = 6081
  protocol             = "GENEVE"
  vpc_id               = var.VPCID
  deregistration_delay = 30
}


resource "aws_lb" "gwlb" {
  name                       = join("", [var.DeploymentName, "-GWLB"])
  internal                   = false
  load_balancer_type         = "gateway"
  subnets                    = var.GWLBESUBNETSID
  enable_deletion_protection = false
  tags = {
    Environment = "PoC"
  }
}


resource "aws_lb_listener" "gwlb-listener" {
  load_balancer_arn = aws_lb.gwlb.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}
