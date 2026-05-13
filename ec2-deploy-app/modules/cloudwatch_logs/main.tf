variable "sns_topic_arn" {
  description = "SNS topic ARN to send WARNING/ERROR alarms to"
}

# ── Log Groups ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "fetcher" {
  name              = "/weather-app/fetcher"
  retention_in_days = 7

  tags = {
    Name = "weather-fetcher-logs"
  }
}

resource "aws_cloudwatch_log_group" "aggregator" {
  name              = "/weather-app/aggregator"
  retention_in_days = 7

  tags = {
    Name = "weather-aggregator-logs"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/weather-app/app"
  retention_in_days = 7

  tags = {
    Name = "weather-app-logs"
  }
}

# ── Metric Filters ────────────────────────────────────────────────
# Counts every line containing WARNING or ERROR in each log group

resource "aws_cloudwatch_log_metric_filter" "fetcher_errors" {
  name           = "fetcher-warnings-errors"
  log_group_name = aws_cloudwatch_log_group.fetcher.name
  pattern        = "?WARNING ?ERROR"

  metric_transformation {
    name      = "FetcherWarningsErrors"
    namespace = "WeatherApp"
    value     = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "aggregator_errors" {
  name           = "aggregator-warnings-errors"
  log_group_name = aws_cloudwatch_log_group.aggregator.name
  pattern        = "?WARNING ?ERROR"

  metric_transformation {
    name      = "AggregatorWarningsErrors"
    namespace = "WeatherApp"
    value     = "1"
    default_value = "0"
  }
}

# ── Alarms ────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "fetcher_errors" {
  alarm_name          = "weather-fetcher-warnings-errors"
  alarm_description   = "Weather fetcher logged a WARNING or ERROR"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FetcherWarningsErrors"
  namespace           = "WeatherApp"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = {
    Name = "weather-fetcher-warnings-errors"
  }
}

resource "aws_cloudwatch_metric_alarm" "aggregator_errors" {
  alarm_name          = "weather-aggregator-warnings-errors"
  alarm_description   = "Weather aggregator logged a WARNING or ERROR"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AggregatorWarningsErrors"
  namespace           = "WeatherApp"
  period              = 3600
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = {
    Name = "weather-aggregator-warnings-errors"
  }
}

# ── Outputs ───────────────────────────────────────────────────────

output "fetcher_log_group_name" {
  value = aws_cloudwatch_log_group.fetcher.name
}

output "aggregator_log_group_name" {
  value = aws_cloudwatch_log_group.aggregator.name
}

output "app_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
