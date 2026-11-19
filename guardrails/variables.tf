variable "alert_email" {
  description = "Email address that gets budget and anomaly alerts"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD"
  type        = number
  default     = 15
}
