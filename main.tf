module "VPC-SPOKES" {
  count          = 3
  source         = "./network"
  DeploymentName = join("", [local.DEPLOYMENTPREFIX, "-", local.NETWORKINFO[count.index].Name])
  VPC_CIDR       = local.NETWORKINFO[count.index].CIDR
  IPv6_ENABLED   = local.IPv6_ENABLED
  APPLIANCE_VPC  = false
}


module "VPC-APPLIANCE" {
  source         = "./network"
  DeploymentName = join("", [local.DEPLOYMENTPREFIX, "-", local.NETWORKINFO[3].Name])
  VPC_CIDR       = local.NETWORKINFO[3].CIDR
  IPv6_ENABLED   = local.IPv6_ENABLED
  APPLIANCE_VPC  = true
}


module "TGW" {
  depends_on     = [module.VPC-SPOKES, module.VPC-APPLIANCE]
  source         = "./tgw"
  DeploymentName = local.DEPLOYMENTPREFIX
  LEFTVPC        = module.VPC-SPOKES[2].VPCID
  LEFTCIDR       = local.NETWORKINFO[2].CIDR
  LEFTSUBNETS    = module.VPC-SPOKES[2].PRIVSUBNETSID
  LEFTROUTES     = module.VPC-SPOKES[2].ROUTES
  RIGHTVPC       = module.VPC-APPLIANCE.VPCID
  RIGHTSUBNETS   = module.VPC-APPLIANCE.PRIVSUBNETSID
  RIGHTROUTES    = module.VPC-APPLIANCE.ROUTES
  RIGHTCIDR      = local.NETWORKINFO[3].CIDR
  VPCNAMES       = local.NETWORKINFO[*].Name
}


module "GWLB" {
  depends_on     = [module.TGW]
  source         = "./gwlb"
  DeploymentName = local.DEPLOYMENTPREFIX
  VPCID          = module.VPC-APPLIANCE.VPCID
  GWLBESUBNETSID = module.VPC-APPLIANCE.PRIVSUBNETSID
}
