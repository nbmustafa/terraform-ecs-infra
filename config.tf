# provider "aws" {
#   region  = "ap-southeast-2"
#   version = "~> 2.22"
# }

# terraform {
#   backend "s3" {
#     region = "ap-southeast-2"
#     key    = "state"
#   }
# }


data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}


provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  # profile    = "default"
  region     = "us-east-1"
}

