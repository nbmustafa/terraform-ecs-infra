# ----------------------------------------------------------
# EC2 Security Group
# ----------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${local.prefix}-ec2-sg"
  description = "Allow ephemeral port range inbound traffic from alb to ec2"
  vpc_id      = data.aws_vpc.vpc.id

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

resource "aws_security_group_rule" "ec2_ingress" {
  type              = "ingress"
  from_port         = 1024
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]
  security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "ec2_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_sg.id
}
