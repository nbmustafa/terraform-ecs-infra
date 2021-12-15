locals {
  region = data.aws_region.current.name
  prefix = "${var.service_name}-${var.app_name}-${var.environment}"
  
  asg_tags = [ 
    { 
      key                 = "AppName"
      value               = var.app_name
      propagate_at_launch = true
    },
    { 
      key                 = "Environment"
      value               = var.environment
      propagate_at_launch = true
    },
    { 
      key                 = "ServiceName"
      value               = var.service_name
      propagate_at_launch = true
    }
  ]
  
}

