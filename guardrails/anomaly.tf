resource "aws_ce_anomaly_monitor" "services" {
  name              = "finops-spike-service-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE" #aka learn a pattern of usage per service and alert if it deviates from that pattern
}


resource "aws_ce_anomaly_subscription" "alerts" {
  name             = "finops-spike-service-alerts"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  #inly alert if the anomaly detected is at least $1
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["1"]
    }
  }
}
