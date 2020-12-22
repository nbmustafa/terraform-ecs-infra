# ----------------------------------------------------------
# ALB Security Group
# ----------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name_prefix = "${local.prefix_name}-alb-sg"
  description = "Allow inbound traffic to alb"
  vpc_id      = data.aws_vpc.vpc.id

  tags = merge(
    {
      Name      = "${local.prefix}-alb-sg"
      Component = "Security Group"
    },
    local.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

# ----------------------------------------------------------
# ALB
# ----------------------------------------------------------
resource "aws_lb" "alb" {
  name               = "${local.prefix}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = data.aws_subnet_ids.subnet_ids.ids

  # access_logs {
  #   bucket  = var.alb_access_logs_bucket
  #   prefix  = "${local.prefix}-alb"
  #   enabled = true
  # }

  tags = merge(
    {
      Name      = "${local.prefix}-alb"
      Component = "ALB"
    },
    local.tags
  )
}

# ----------------------------------------------------------
# ALB https_listener
# ----------------------------------------------------------
resource "aws_lb_listener" "alb_https_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = ""
      status_code  = "404"
    }
  }
}

# ----------------------------------------------------------
# Route53 record for ALB
# ----------------------------------------------------------
data "aws_route53_zone" "hosted_zone" {
  name         = var.record_set_name
  private_zone = true
}

resource "aws_route53_record" "alb_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "${var.environment}.${var.app_name}"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = false
  }
}