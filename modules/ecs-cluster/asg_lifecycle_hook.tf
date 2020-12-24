# ----------------------------------------------------------
# asg lifecycle hooks and its iam role
# ----------------------------------------------------------
resource "aws_autoscaling_lifecycle_hook" "container_draining" {
  name                    = "container-draining-lifecycle-hook"
  autoscaling_group_name  = aws_autoscaling_group.ecs_asg.name
  default_result          = "ABANDON"
  heartbeat_timeout       = 900
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = aws_sns_topic.container_draining_sns_topic.arn
  role_arn                = aws_iam_role.lifecycle_hook_iam_role.arn

  notification_metadata = <<EOF
  {
    "CLUSTER_NAME": "${aws_ecs_cluster.ecs_cluster.name}"
  }
  EOF
}

resource "aws_iam_role" "lifecycle_hook_iam_role" {
  name                  = "${local.prefix}-asg-hooks-container-draining-role"
  force_detach_policies = true
  
  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "autoscaling.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF 
}

resource "aws_iam_role_policy_attachment" "lifecycle_hook_asn_access_policy" {
  role       = aws_iam_role.lifecycle_hook_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

# ----------------------------------------------------------
# sns topic 
# ----------------------------------------------------------
resource "aws_sns_topic" "container_draining_sns_topic" {
  name = "${local.prefix}-container-draining-topic"
}

resource "aws_sns_topic_subscription" "container_draining_sns_subscription" {
  topic_arn = aws_sns_topic.container_draining_sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.container_draining_lambda.arn
}

# ----------------------------------------------------------
# Lambda Function
# ----------------------------------------------------------
data "archive_file" "container_draining_zip" {
  type        = "zip"
  output_path = "${path.module}/tmp/lambdas/container_draining-${sha256(file("${path.module}/lambdas/container_draining.py"))}.zip"
  source_file = "${path.module}/lambdas/container_draining.py"
}

resource "aws_lambda_function" "container_draining_lambda" {
  handler          = "container_draining.lambda_handler"
  function_name    = "${local.prefix}-container-draining-lambda"
  role             = aws_iam_role.container_draining_lambda_role.arn
  runtime          = "python3.6"
  filename         = data.archive_file.container_draining_zip.output_path
  source_code_hash = data.archive_file.container_draining_zip.output_base64sha256

  timeout = "300"

  vpc_config {
    security_group_ids = [data.aws_security_group.vpc_default_sg.id]
    subnet_ids         = data.aws_subnet_ids.subnet_ids.ids
  }

  environment {
    variables = {
      FORWARD_PROXY = "http://forwardproxy:3128"
    }
  }

  tags = merge(
    {
      Name      = "${local.prefix}-container-draining-lambda"
      Component = "Lambda Function"
    },
    var.tags
  )
}

resource "aws_lambda_alias" "container_draining_lambda_alias" {
  name             = aws_lambda_function.container_draining_lambda.function_name
  description      = aws_lambda_function.container_draining_lambda.function_name
  function_name    = aws_lambda_function.container_draining_lambda.arn
  function_version = "$LATEST"
}

resource "aws_lambda_permission" "container_draining_lambda_permission" {
  function_name = aws_lambda_function.container_draining_lambda.arn
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.container_draining_sns_topic.arn
}

resource "aws_iam_role" "container_draining_lambda_role" {
  name                  = "${local.prefix}-container-draining-lambda-assume-role"
  force_detach_policies = true
  
  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF 
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec_policy" {
  role       = aws_iam_role.container_draining_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "autoscaling_notification_policy" {
  role       = aws_iam_role.container_draining_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

resource "aws_iam_role_policy" "container_draining_lambda_policy" {
  name = "${local.prefix}-container-draining-lambda-role-policy"
  role = aws_iam_role.container_draining_lambda_role.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:CompleteLifecycleAction",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceAttribute",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeHosts",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface",
        "ecs:ListContainerInstances",
        "ecs:SubmitContainerStateChange",
        "ecs:SubmitTaskStateChange",
        "ecs:DescribeContainerInstances",
        "ecs:UpdateContainerInstancesState",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "sns:Publish",
        "sns:ListSubscriptions"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
