variable "asg_min_size" {
  type        = string
  description = "Minimum size of auto scaling group"
  default     = 2
}

# variable "alb_access_logs_bucket" {
#   type        = string
#   description = "The name of the S3 bucket where the ALB access logs are to be outputted to"
# }

variable "asg_max_size" {
  type        = string
  description = "Maximum size of auto scaling group"
  default     = 4
}

variable "asg_power_min_size" {
  type        = string
  description = "Minimum size of Power Management Tag"
  default     = 0
}

variable "asg_desired_capacity" {
  type        = string
  description = "Desired number of auto scaling group"
  default     = 2
}

variable "asg_power_mgt_code" {
  type        = string
  description = "Power management calendar of auto scaling group"
  default     = "24x7"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type to be launched in the ECS cluster"
  default     = "t2.medium"
}

variable "proxy_host" {
  type        = string
  description = "Host proxy of the EC2 instances launched in the ECS cluster"
  default     = "forwardproxy"
}

# variable "iam_policy_arn" {
#   type        = list(string)
#   description = "IAM Policies to attach to the IAM role to be used by the EC2 instances launched"
# }

variable "certificate_arn" {
  type        = string
  description = "ARN of the SSL certificate to be used by the load balancer"
}

variable "iam_name_prefix" {
  type        = string
  description = "IAM role with format <iam_name_prefix_>ProvisioningInstanceProfile"
}

variable "cost_centre" {
  type        = string
  description = "Project cost centre tag value"
}

variable "application_id" {
  type        = string
  description = "Application ID tag value"
}

variable "service_name" {
  type        = string
  description = "Service name used to namespace the resources created in AWS"
  default     = "nabx"
}

variable "app_name" {
  type        = string
  description = "Application name used to namespace the resources created in AWS"
  default     = "example"
}

variable "environment" {
  type        = string
  description = "Environment name for namespacing the resources created in AWS"
  default     = "develop"
}

variable "owner" {
  default     = "Nash Support"
  type        = string
  description = "The resource owner to tag all the resources with"
}

variable "record_set_name" {
  type        = string
  description = "Name of the zone that will be used by the Route 53 record of the cluster's ALB"
}

variable "disable_api_termination" {
  type        = string
  description = "If true, enables EC2 Instance Termination Protection"
  default     = true
}

variable "ondemand_percentage" {
  type        = string
  description = ""
  default     = "100"
}

variable "spot_price" {
  type        = string
  description = "Maximum price per unit hour to pay for the Spot instances"
  default     = "0.50"
}

## auto-scaling-policy variables
variable "enabled" {
  type        = string
  description = "Whether to create the resources. Set to `false` to prevent the module from creating any resources"
  default     = "true"
}

variable "autoscaling_policies_enabled" {
  type        = bool
  default     = true
  description = "Whether to create `aws_autoscaling_policy` and `aws_cloudwatch_metric_alarm` resources to control Auto Scaling"
}

variable "scale_up_cooldown_seconds" {
  type        = number
  default     = 300
  description = "The amount of time, in seconds, after a scaling activity completes and before the next scaling activity can start"
}

variable "scale_up_scaling_adjustment" {
  type        = number
  default     = 1
  description = "The number of instances by which to scale. `scale_up_adjustment_type` determines the interpretation of this number (e.g. as an absolute number or as a percentage of the existing Auto Scaling group size). A positive increment adds to the current capacity and a negative value removes from the current capacity"
}

variable "scale_up_adjustment_type" {
  type        = string
  default     = "ChangeInCapacity"
  description = "Specifies whether the adjustment is an absolute number or a percentage of the current capacity. Valid values are `ChangeInCapacity`, `ExactCapacity` and `PercentChangeInCapacity`"
}

variable "scale_up_policy_type" {
  type        = string
  default     = "SimpleScaling"
  description = "The scalling policy type, either `SimpleScaling`, `StepScaling` or `TargetTrackingScaling`"
}

variable "scale_down_cooldown_seconds" {
  type        = number
  default     = 300
  description = "The amount of time, in seconds, after a scaling activity completes and before the next scaling activity can start"
}

variable "scale_down_scaling_adjustment" {
  type        = number
  default     = -1
  description = "The number of instances by which to scale. `scale_down_scaling_adjustment` determines the interpretation of this number (e.g. as an absolute number or as a percentage of the existing Auto Scaling group size). A positive increment adds to the current capacity and a negative value removes from the current capacity"
}

variable "scale_down_adjustment_type" {
  type        = string
  default     = "ChangeInCapacity"
  description = "Specifies whether the adjustment is an absolute number or a percentage of the current capacity. Valid values are `ChangeInCapacity`, `ExactCapacity` and `PercentChangeInCapacity`"
}

variable "scale_down_policy_type" {
  type        = string
  default     = "SimpleScaling"
  description = "The scalling policy type, either `SimpleScaling`, `StepScaling` or `TargetTrackingScaling`"
}

variable "cpu_utilization_high_evaluation_periods" {
  type        = number
  default     = 2
  description = "The number of periods over which data is compared to the specified threshold"
}

variable "cpu_utilization_high_period_seconds" {
  type        = number
  default     = 300
  description = "The period in seconds over which the specified statistic is applied"
}

variable "cpu_utilization_high_threshold_percent" {
  type        = number
  default     = 90
  description = "The value against which the specified statistic is compared"
}

variable "cpu_utilization_high_statistic" {
  type        = string
  default     = "Average"
  description = "The statistic to apply to the alarm's associated metric. Either of the following is supported: `SampleCount`, `Average`, `Sum`, `Minimum`, `Maximum`"
}

variable "cpu_utilization_low_evaluation_periods" {
  type        = number
  default     = 2
  description = "The number of periods over which data is compared to the specified threshold"
}

variable "cpu_utilization_low_period_seconds" {
  type        = number
  default     = 300
  description = "The period in seconds over which the specified statistic is applied"
}

variable "cpu_utilization_low_threshold_percent" {
  type        = number
  default     = 30
  description = "The value against which the specified statistic is compared"
}

variable "cpu_utilization_low_statistic" {
  type        = string
  default     = "Average"
  description = "The statistic to apply to the alarm's associated metric. Either of the following is supported: `SampleCount`, `Average`, `Sum`, `Minimum`, `Maximum`"
}
