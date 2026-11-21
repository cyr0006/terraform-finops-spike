variable "instance_name" {
  description = "Value of instance's Name tag"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (restricted to small cheap ones due to proverty)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t4g.micro", "t4g.small"], var.instance_type)
    error_message = "Instance type must be one of: t3.micro, t3.small, t4g.micro, t4g.small"
  }
}

variable "root_volume_size_gb" {
  description = "Size of gp3 root volume in GB"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size_gb >= 8 && var.root_volume_size_gb <= 20
    error_message = "Root volume must be beteen 8 and 20 GB"
  }
}

variable "associate_public_ip" {
  description = "Give the instance a public IPv4 address (billed hourly)"
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "AZ to launch the instance in (uses that AZ's default subnet)"
  type        = string
  default     = "ap-southeast-2a"
}
