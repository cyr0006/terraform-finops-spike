terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
  }

  # Specify the required version of Terraform itself
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "finops-spike-tfstate-502869772083"
    key          = "finops-spike/main/terraform.tfstate" # path inside the bucket
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Owner       = "aryan"
      CostCentre  = "learning"
      Environment = "sandbox"
      Project     = "finops-spike"
    }
  }
}
