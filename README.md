# terraform-finops-spike

A small Terraform project for learning the basics of Terraform on AWS, based on the HashiCorp developer tutorial.

It creates:

- A VPC in the Sydney region (`ap-southeast-2`) with two public and two private subnets, using the community [VPC module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- One EC2 instance running the latest Amazon Linux 2023, placed in the first public subnet

## Files

| File | Purpose |
|---|---|
| `terraform.tf` | Terraform and AWS provider versions, and the AWS region |
| `variables.tf` | Input variables (instance type and name) |
| `main.tf` | The VPC module, the AMI lookup and the EC2 instance |
| `outputs.tf` | Values printed after `apply` (the instance's private DNS name) |

## Requirements

- Terraform 1.2 or later
- An AWS account with credentials set up locally (for example with `aws configure`)

## Usage

```sh
terraform init      # download the provider and modules
terraform plan      # preview the changes
terraform apply     # create the resources
terraform destroy   # remove everything when finished
```

To change the instance settings, override the variables:

```sh
terraform apply -var="instance_type=t3.small" -var="instance_name=my-instance"
```

## Variables

| Name | Default | Description |
|---|---|---|
| `instance_type` | `t3.micro` | EC2 instance type |
| `instance_name` | `terraform-spike` | Value of the instance's `Name` tag |

## Cost

The EC2 instance is billed for as long as it is running. Run `terraform destroy` when you are done.
