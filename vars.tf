variable "service_name" {
  default     = "xyz"
  type        = string
  description = "The service name that all resources will be tagged with"
}

variable "app_name" {
  type        = string
  description = "The app name that all resources will be tagged with"
}

variable "environment" {
  default     = "dev"
  type        = string
  description = "The development stage this deployment is for, e.g. dev01, sit02, prod01"
}
