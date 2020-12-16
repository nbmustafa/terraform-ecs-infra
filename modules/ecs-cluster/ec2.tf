data "aws_iam_role" "provisioning-instance-profile" {
  name = "${var.iam_name_prefix}ProvisioningInstanceProfile"
}

data "aws_iam_policy" "ec2-container-service-policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy_document" "ecs-instance-role-policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ecs-instance-role" {
  name                  = "${local.prefix}-ecs-instance-role"
  force_detach_policies = true

  assume_role_policy = data.aws_iam_policy_document.ecs-instance-role-policy.json
}

resource "aws_iam_role_policy_attachment" "ecs-role-policy-attachment" {
  role       = aws_iam_role.ecs-instance-role.name
  policy_arn = data.aws_iam_policy.ec2-container-service-policy.arn
}

resource "aws_iam_role_policy_attachment" "hip-role-policy-attachment" {
  role       = aws_iam_role.ecs-instance-role.name
  count      = length(var.iam_policy_arn)
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.iam_policy_arn[count.index]}"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
  name = "${local.prefix}-ecs-instance-profile"
  role = aws_iam_role.ecs-instance-role.name
}

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
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]
    principals {
      type = "AWS"
      identifiers = [
        data.aws_iam_role.provisioning-instance-profile.arn
      ]
    }
    resources = [
      "*"
    ]
  }
  statement {
    sid = "Autoscale to decrypt on startup"
    actions = [
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:DescribeKey",
      "kms:GenerateDataKey*"
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.ecs-instance-role.arn,
        data.aws_iam_role.provisioning-instance-profile.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
    resources = [
      "*"
    ]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.ap-southeast-2.amazonaws.com"]
    }
  }
  statement {
    sid = "Allow attachment of persistent resources"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.ecs-instance-role.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
    resources = [
      "*"
    ]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
  statement {
    sid    = "DenyAWSRegion"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = [
      "kms:*"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-southeast-2"]
    }
  }
}

resource "aws_kms_key" "axt-base-ami-kms-key" {
  description         = "Key used to encrypt the EBS snapshots when copying the HIP base AMI"
  enable_key_rotation = true

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = {
    "ApplicationID" = var.application_id
    "CostCentre"    = var.cost_centre
  }
}

resource "aws_launch_template" "ecs-launch-template" {
  name = "${local.prefix}-ecs-launch-template"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      encrypted   = true
      kms_key_id  = aws_kms_key.axt-base-ami-kms-key.arn
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdcz"
    ebs {
      volume_size = 22
      encrypted   = true
      kms_key_id  = aws_kms_key.axt-base-ami-kms-key.arn
    }
  }

  disable_api_termination = var.disable_api_termination

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs-instance-profile.arn
  }

  image_id = data.aws_ami.hip-ami.id
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.ec2-sg.id]
  user_data = base64encode(data.template_file.user-data.rendered)
}

resource "aws_cloudformation_stack" "ecs-autoscaling-group" {
  name = "${local.prefix}-ecs-asg"

  parameters = {
    VPCZoneIdentifier = join(",", data.aws_subnet_ids.subnet-ids.ids)
  }

  template_body = <<EOF
{
  "Parameters" : {
    "VPCZoneIdentifier" : {
      "Type": "List<AWS::EC2::Subnet::Id>"
    }
  },
  "Resources": {
    "ASG": {
      "Type": "AWS::AutoScaling::AutoScalingGroup",
      "Properties": {
        "AutoScalingGroupName": "${var.service_name}-${var.app_name}-${var.environment}-ecs-asg",
        "VPCZoneIdentifier": {
          "Ref" : "VPCZoneIdentifier"
        },
        "MaxSize": ${var.asg_max_size},
        "MinSize": ${var.asg_min_size},
        "HealthCheckType": "EC2",
        "HealthCheckGracePeriod": 300,
        "MixedInstancesPolicy" : {
          "InstancesDistribution": {
            "OnDemandAllocationStrategy": "prioritized",
            "OnDemandBaseCapacity": 0,
            "OnDemandPercentageAboveBaseCapacity": ${var.ondemand_percentage},
            "SpotAllocationStrategy": "lowest-price",
            "SpotInstancePools": 2,
            "SpotMaxPrice": "${var.spot_price}"
          },
          "LaunchTemplate": {
            "LaunchTemplateSpecification": {
              "LaunchTemplateId": "${aws_launch_template.ecs-launch-template.id}",
              "Version": "${aws_launch_template.ecs-launch-template.latest_version}"
            }
          }
        },
        "Tags": [
        {
          "Key": "Name",
          "Value": "${var.service_name}-${var.app_name}-${var.environment}-instance",
          "PropagateAtLaunch": true
        },
        {
          "Key": "ApplicationID",
          "Value": "${var.application_id}",
          "PropagateAtLaunch": true
        },
        {
          "Key": "CostCentre",
          "Value": "${var.cost_centre}",
          "PropagateAtLaunch": true
        },
        {
          "Key": "PowerMgt",
          "Value": "${var.asg_power_mgt_code}",
          "PropagateAtLaunch": true
        }
        ]
      },
      "CreationPolicy": {
        "AutoScalingCreationPolicy": {
          "MinSuccessfulInstancesPercent": 100
        },
        "ResourceSignal": {
          "Count": ${var.asg_desired_capacity},
          "Timeout": "PT20M"
        }
      },
      "UpdatePolicy": {
        "AutoScalingRollingUpdate": {
          "MinInstancesInService": ${var.asg_min_size},
          "MaxBatchSize": 2,
          "MinSuccessfulInstancesPercent": 80,
          "PauseTime": "PT10M",
          "WaitOnResourceSignals": true,
          "SuspendProcesses": ["AlarmNotification", "ScheduledActions", "HealthCheck", "ReplaceUnhealthy", "AZRebalance"]
        }
      }
    }
  },
  "Outputs": {
    "AsgName": {
      "Description": "The name of the auto scaling group",
       "Value": {
          "Ref": "ASG"
      }
    }
  }
}
EOF

  # create a new one before destroy old one when a resource must be re-created upon a requested change
  lifecycle {
    create_before_destroy = true
  }
}

locals {
  autoscaling_enabled = var.enabled && var.autoscaling_policies_enabled ? true : false
}

resource "aws_autoscaling_policy" "scale_up" {
  count                  = local.autoscaling_enabled ? 1 : 0
  name                   = "${local.prefix}-ecs-cluster-scale-up"
  scaling_adjustment     = var.scale_up_scaling_adjustment
  adjustment_type        = var.scale_up_adjustment_type
  policy_type            = var.scale_up_policy_type
  cooldown               = var.scale_up_cooldown_seconds
  autoscaling_group_name = aws_cloudformation_stack.ecs-autoscaling-group.outputs["AsgName"]
}

resource "aws_autoscaling_policy" "scale_down" {
  count                  = local.autoscaling_enabled ? 1 : 0
  name                   = "${local.prefix}-ecs-cluster-scale-down"
  scaling_adjustment     = var.scale_down_scaling_adjustment
  adjustment_type        = var.scale_down_adjustment_type
  policy_type            = var.scale_down_policy_type
  cooldown               = var.scale_down_cooldown_seconds
  autoscaling_group_name = aws_cloudformation_stack.ecs-autoscaling-group.outputs["AsgName"]
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
    AutoScalingGroupName = aws_cloudformation_stack.ecs-autoscaling-group.outputs["AsgName"]
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
    AutoScalingGroupName = aws_cloudformation_stack.ecs-autoscaling-group.outputs["AsgName"]
  }
}
