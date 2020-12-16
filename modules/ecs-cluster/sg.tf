resource "aws_security_group" "ec2-sg" {
  name_prefix = "${local.prefix}-ec2-sg"
  description = "Allow ephemeral port range inbound traffic from alb"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port       = 1024
    to_port         = 65535
    protocol        = "tcp"
    # cidr_blocks = ["${data.aws_vpc.vpc.cidr_block}"]
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name      = "${local.prefix}-ec2-sg"
      Component = "Security Group"
    },
    local.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}
