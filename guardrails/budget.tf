resource "aws_budgets_budget" "monthly" {
  name         = "finops-spike-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd) #aws apparently expects a string for limit_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = false #to real consumption, not usage - credits which would mean cost is technically $0 UNTIL you run out of credits; misleading for FinOps
    include_refund = false
  }



  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
