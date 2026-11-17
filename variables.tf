variable "instance_type" {
  description = "The type of instance to use"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "The name of the instance"
  type        = string
  default     = "terraform-spike"
}
