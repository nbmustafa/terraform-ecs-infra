# ----------------------------------------------------------
# EC2 IAM role, policies, and Instance profile
# ----------------------------------------------------------
data "aws_iam_policy_document" "ecs_instance_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name                  = "${local.prefix}-ecs-instance-role"
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.ecs_instance_role_policy.json
}

resource "aws_iam_role_policy" "ecsInstancerolePolicy" {
  name   = "${local.prefix}-ecs-instance-role-policy"
  role   = aws_iam_role.ecs_instance_role.id
  policy = var.ecsInstancerolePolicy
}

variable "ecsInstancerolePolicy" {
  type = string

  default = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecsInstanceProfile" {
  name = "${local.prefix}-ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# resource "aws_iam_instance_profile" "ecs_instance_profile" {
#   name = "${local.prefix}-ecs-instance-profile"
#   role = aws_iam_role.ecs_instance_role.name
# }

resource "aws_iam_role" "ecsServiceRole" {
  name               = "${local.prefix}-ecsServiceRole"
  assume_role_policy = var.ecsServiceRoleAssumeRolePolicy
}

resource "aws_iam_role_policy" "ecsServiceRolePolicy" {
  name   = "${local.prefix}-ecsServiceRolePolicy"
  role   = aws_iam_role.ecsServiceRole.id
  policy = var.ecsServiceRolePolicy
}

variable "ecsServiceRoleAssumeRolePolicy" {
  type = string

  default = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

variable "ecsServiceRolePolicy" {
  default = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# ----------------------------------------------------------
# KMS and its Policy
# ----------------------------------------------------------
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid = "Enable IAM User Permissions"
    actions = [
      "kms:*"
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
    resources = [
      "*"
    ]
  }
  statement {
    sid = "Allow access for Key Administrators"
    actions = [
      "kms:*",
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.ecs_instance_role.arn,
        aws_iam_instance_profile.ecsInstanceProfile.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
      ]
    }
    resources = [
      "*",
    ]
  }
}

# kms key for volume encryption
resource "aws_kms_key" "ami_kms_key" {
  description         = "Key used to encrypt the EBS snapshots when copying the HIP base AMI"
  enable_key_rotation = true

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = {
    "ApplicationID" = var.application_id
    "CostCentre"    = var.cost_centre
  }
}

# ----------------------------------------------------------
# Launch_template
# ----------------------------------------------------------
resource "aws_launch_template" "ecs_launch_template" {
  name = "${local.prefix}-ecs-launch-template"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      encrypted   = true
      kms_key_id  = aws_kms_key.ami_kms_key.arn
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdcz"
    ebs {
      volume_size = 30
      encrypted   = true
      kms_key_id  = aws_kms_key.ami_kms_key.arn
    }
  }

  disable_api_termination = var.disable_api_termination

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecsInstanceProfile.arn
  }

  image_id      = data.aws_ami.ecs_ami.id
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = base64encode(data.template_file.user_data.rendered)
}

# ----------------------------------------------------------
# Auto-Scaling Group
# ----------------------------------------------------------
resource "aws_autoscaling_group" "ecs_asg" {
  name                      = "${local.prefix}-ecs-asg"
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  default_cooldown          = 300
  health_check_grace_period = 300
  health_check_type         = "EC2"
  protect_from_scale_in     = "false"
  termination_policies      = ["OldestInstance", "Default"]
  vpc_zone_identifier       = data.aws_subnet_ids.subnet_ids.ids

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs_launch_template.id
        version            = aws_launch_template.ecs_launch_template.latest_version
      }

      # override {
      #   instance_type = "t3a.large"
      #   # weighted_capacity = "2"
      # }
      # override {
      #   instance_type     = "c3.large"
      #   # weighted_capacity = "2"
      # }

    }
    instances_distribution {
      on_demand_allocation_strategy            = "prioritized"
      on_demand_base_capacity                  = "1"
      on_demand_percentage_above_base_capacity = "50"
      spot_allocation_strategy                 = "lowest-price"
      spot_instance_pools                      = "2"
      spot_max_price                           = var.spot_price
    }
  }

  lifecycle {
    ignore_changes        = [desired_capacity]
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      # instance_warmup = 120 
      min_healthy_percentage  = 50
    }
    # triggers = ["tag"]
  }

  depends_on = [aws_launch_template.ecs_launch_template]

  timeouts {
    delete = "20m"
  }

  tags = [merge(
    {
      Name      = "${local.prefix}-auto-scaling-group"
      Component = "Auto-Scaling-Group"
    },
    local.tags
  )]
  # tags = [local.tags]

}

# ----------------------------------------------------------
# locals
# ----------------------------------------------------------
locals {
  autoscaling_enabled = var.enabled && var.autoscaling_policies_enabled ? true : false
}

# ----------------------------------------------------------
# Auto-scaling group Policies
# ----------------------------------------------------------
resource "aws_autoscaling_policy" "scale_up" {
  count                  = local.autoscaling_enabled ? 1 : 0
  name                   = "${local.prefix}-ecs-cluster-scale-up"
  scaling_adjustment     = var.scale_up_scaling_adjustment
  adjustment_type        = var.scale_up_adjustment_type
  policy_type            = var.scale_up_policy_type
  cooldown               = var.scale_up_cooldown_seconds
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  count                  = local.autoscaling_enabled ? 1 : 0
  name                   = "${local.prefix}-ecs-cluster-scale-down"
  scaling_adjustment     = var.scale_down_scaling_adjustment
  adjustment_type        = var.scale_down_adjustment_type
  policy_type            = var.scale_down_policy_type
  cooldown               = var.scale_down_cooldown_seconds
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = local.autoscaling_enabled ? 1 : 0
  alarm_name          = "${local.prefix}-ecs-cluster-cpu-utilization-high"
  alarm_description   = "Scale up if CPU utilization is above ${var.cpu_utilization_high_threshold_percent} for ${var.cpu_utilization_high_period_seconds} seconds"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.cpu_utilization_high_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cpu_utilization_high_period_seconds
  statistic           = var.cpu_utilization_high_statistic
  threshold           = var.cpu_utilization_high_threshold_percent
  alarm_actions       = ["${aws_autoscaling_policy.scale_up.0.arn}"]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count               = local.autoscaling_enabled ? 1 : 0
  alarm_name          = "${local.prefix}-ecs-cluster-cpu-utilization-low"
  alarm_description   = "Scale down if the CPU utilization is below ${var.cpu_utilization_low_threshold_percent} for ${var.cpu_utilization_low_period_seconds} seconds"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.cpu_utilization_low_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cpu_utilization_low_period_seconds
  statistic           = var.cpu_utilization_low_statistic
  threshold           = var.cpu_utilization_low_threshold_percent
  alarm_actions       = ["${aws_autoscaling_policy.scale_down.0.arn}"]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs_asg.name
  }
}
