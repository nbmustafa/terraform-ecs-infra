locals {
  region = data.aws_region.current.name
  prefix = "${var.service_name}-${var.app_name}-${var.environment}"
}

