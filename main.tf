# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" # where the module lives
  version = "~>6.8"                         # a way of pining version , means version 6.8 onwards but less than 7.0

  name            = "spike-vpc"
  cidr            = "10.0.0.0/16" # the network's IP address range
  azs             = ["ap-southeast-2a", "ap-southeast-2b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
}

resource "aws_instance" "spike" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnets[0]

  tags = {
    Name = var.instance_name
  }
}
