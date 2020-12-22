variable "service_name" {
  default     = "xyz"
  type        = string
  description = "The service name that all resources will be tagged with"
}

variable "app_name" {
  default     = "abc"
  type        = string
  description = "The app name that all resources will be tagged with"
}

variable "environment" {
  default     = "develop"
  type        = string
  description = "The development stage this deployment is for, e.g. dev01, sit02, prod01"
}

variable "aws_access_key" {}
variable "aws_secret_key" {}

variable environment_name {
  type    = string
  default = "develop"
}