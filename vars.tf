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
  type    = string
  default = "dev"
}

variable "aws_access_key" {}
variable "aws_secret_key" {}

variable environment_name {
  type    = string
  default = "dev"
}
