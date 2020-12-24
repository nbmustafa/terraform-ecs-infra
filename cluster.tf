module "ecs-cluster" {
  source = "./modules/ecs-cluster"

  environment             = var.environment
  # alb_access_logs_bucket  = local.alb_access_logs_bucket
  app_name                = local.app_name
  application_id          = local.application_id
  cost_centre             = local.cost_centre
  proxy_host              = local.proxy_host
  service_name            = local.service_name
  disable_api_termination = local.disable_api_termination
  iam_name_prefix         = local.iam_name_prefix
  asg_desired_capacity    = local.account_config["asg_desired_capacity"]
  asg_max_size            = local.account_config["asg_max_size"]
  asg_min_size            = local.account_config["asg_min_size"]
  asg_power_mgt_code      = local.account_config["asg_power_mgt_code"]
  certificate_arn         = local.account_config["certificate_arn"]
  instance_type           = local.account_config["instance_type"]
  ondemand_percentage     = local.account_config["ondemand_percentage"]
  record_set_name         = local.account_config["record_set_name"]
  spot_price              = local.account_config["spot_price"]
  
  tags = {
    ApplicationID = local.application_id
    CostCentre    = local.cost_centre
    ServiceName   = local.service_name
    Environment   = var.environment
  }
}
