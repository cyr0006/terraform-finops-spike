variable "instance_type" {
  description = "The type of the EC2 instance to use"
  type        = string
  default     = "t4g.micro"
}

variable "instance_name" {
  description = "The name of the EC2 instance"
  type        = string
  default     = "terraform-spike"
}
