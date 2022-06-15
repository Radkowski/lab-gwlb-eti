locals {
  user_data        = fileexists("./config.yaml") ? yamldecode(file("./config.yaml")) : jsondecode(file("./config.json"))
  REGION           = local.user_data.Parameters.Region
  DEPLOYMENTPREFIX = local.user_data.Parameters.DeploymentPrefix
  NETWORKINFO      = local.user_data.VPCs
  IPv6_ENABLED     = local.user_data.Parameters.IPv6_ENABLED
}
