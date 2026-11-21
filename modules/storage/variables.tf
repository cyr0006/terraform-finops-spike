variable "bucket_prefix" {
  description = "Prefix for the bucket name (AWS adds a random suffix)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,37}$", var.bucket_prefix))
    error_message = "Use 3-37 lowercase letters, numbers or hyphens"
  }
}

variable "noncurrent_version_expiry_days" {
  description = "delete old object versions after this many days"
  type        = number
  default     = 30
}
