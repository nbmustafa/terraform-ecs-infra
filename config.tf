provider "aws" {
  region  = "ap-southeast-2"
  version = "~> 2.22"
}

terraform {
  backend "s3" {
    region = "ap-southeast-2"
    key    = "state"
  }
}
