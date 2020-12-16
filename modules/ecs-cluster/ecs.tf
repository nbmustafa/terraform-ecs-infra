resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${local.prefix}-ecs-cluster"

  tags = merge(
    {
      Name      = "${local.prefix}--ecs-cluster"
      Component = "ECS Cluster"
    },
    local.tags
  )
}
