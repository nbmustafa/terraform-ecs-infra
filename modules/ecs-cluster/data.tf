data aws_region current {
}

data aws_caller_identity current {
}

data aws_vpc vpc {
  filter {
    name   = "tag:Name"
    values = ["*default*"]
  }
}

data aws_subnet_ids subnet_ids {
  vpc_id = data.aws_vpc.vpc.id
}

data aws_security_group vpc_default_sg {
  vpc_id = data.aws_vpc.vpc.id
  name   = "default"
}

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }
}

# data "aws_ssm_parameter" "ecs_ami" {
#   name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
# }
# image_id      = data.aws_ssm_parameter.ecs_ami.value


# data "template_file" "user_data" {
#   template = file("${path.module}/templates/user-data.sh")

#   vars = {
#     cluster_name = aws_ecs_cluster.ecs_cluster.name
#     proxy_host   = var.proxy_host
#     aws_region   = data.aws_region.current.name
#     stack_name   = "${var.service_name}-${var.app_name}-${var.environment}-ecs-asg"
#     resource     = "ASG"
#   }
# }

data "template_file" "user_data" {
  template = file("${path.module}/templates/default-user-data.sh")

  vars = {
    ecs_cluster_name = aws_ecs_cluster.ecs_cluster.name
  }
}