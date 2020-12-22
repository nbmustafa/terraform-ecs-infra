locals {
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name
  ecs_cluster_name       = aws_ecs_cluster.ecs_cluster.name
}

# asg lifecycle hooks
resource "aws_autoscaling_lifecycle_hook" "container-draining" {
  name                    = "container-draining-lifecycle-hook"
  autoscaling_group_name  = aws_autoscaling_group.ecs_asg.name
  default_result          = "ABANDON"
  heartbeat_timeout       = 900
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = aws_sns_topic.container-draining-sns-topic.arn
  role_arn                = aws_iam_role.container-draining_asg_lifecycle_hook.arn

  depends_on = [ aws_iam_role_policy_attachment.container-draining_asg_lifecycle_hook-asn-access ]

  notification_metadata = <<EOF
{
  "CLUSTER_NAME": "${local.ecs_cluster_name}"
}
EOF
}

resource "aws_iam_role" "container-draining_asg_lifecycle_hook" {
  name                  = "${local.prefix}-asg-hooks-container-draining-role"
  assume_role_policy    = file("${path.module}/policies/autoscaling_assume_role.json")
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "container-draining_asg_lifecycle_hook-asn-access" {
  role       = aws_iam_role.container-draining_asg_lifecycle_hook.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

# sns
resource "aws_sns_topic" "container-draining-sns-topic" {
  name = "${local.prefix}-container-draining-topic"
}

resource "aws_sns_topic_subscription" "container-draining-sns-subscription" {
  topic_arn = aws_sns_topic.container-draining-sns-topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.container-draining_lambda.arn
}

# lambda
data "archive_file" "container-draining_zip" {
  type        = "zip"
  output_path = "${path.module}/tmp/lambdas/container_draining-${sha256(file("${path.module}/lambdas/container_draining.py"))}.zip"
  source_file = "${path.module}/lambdas/container_draining.py"
}

resource "aws_lambda_function" "container-draining_lambda" {
  handler          = "container_draining.lambda_handler"
  function_name    = "${local.prefix}-container-draining-lambda"
  role             = aws_iam_role.container-draining-lambda-role.arn
  runtime          = "python3.6"
  filename         = data.archive_file.container-draining_zip.output_path
  source_code_hash = data.archive_file.container-draining_zip.output_base64sha256

  timeout = "300"

  tags = merge(
    {
      Name      = "${local.prefix}-container-draining-lambda"
      Component = "Lambda"
    },
    local.tags
  )

  vpc_config {
    security_group_ids = [data.aws_security_group.vpc-default-sg.id]
    subnet_ids         = data.aws_subnet_ids.subnet_ids.ids
  }

  environment {
    variables = {
      FORWARD_PROXY = "http://forwardproxy:3128"
    }
  }
}

resource "aws_lambda_alias" "container-draining_lambda" {
  name             = aws_lambda_function.container-draining_lambda.function_name
  description      = aws_lambda_function.container-draining_lambda.function_name
  function_name    = aws_lambda_function.container-draining_lambda.arn
  function_version = "$LATEST"
}

resource "aws_lambda_permission" "container-draining_lambda" {
  function_name = aws_lambda_function.container-draining_lambda.arn

  statement_id = "AllowExecutionFromSNS"
  action       = "lambda:InvokeFunction"
  principal    = "sns.amazonaws.com"

  source_arn = aws_sns_topic.container-draining-sns-topic.arn
}

resource "aws_iam_role" "container-draining-lambda-role" {
  name                  = "${local.prefix}-container-draining-lambda-assume-role"
  assume_role_policy    = file("${path.module}/policies/lambda_assume_role.json")
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "container-draining_lambda-basic-exec" {
  role       = aws_iam_role.container-draining-lambda-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "container-draining_lambda-autoscaling-notification" {
  role       = aws_iam_role.container-draining-lambda-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

resource "aws_iam_role_policy" "container-draining_lambda" {
  name = "${local.prefix}-container-draining-lambda-role-policy"
  role = aws_iam_role.container-draining-lambda-role.name

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
