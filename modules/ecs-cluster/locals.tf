locals {
  prefix = "${var.service_name}-${var.app_name}-${var.environment}"
  tags = {
    ApplicationID = var.application_id
    CostCentre    = var.cost_centre
    ServiceName   = var.service_name
    Environment   = var.environment
  }
}

