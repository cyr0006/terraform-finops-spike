terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
  }

  # Specify the required version of Terraform itself
  required_version = ">= 1.2"
}

provider "aws" {
  region = "ap-southeast-2"
}
