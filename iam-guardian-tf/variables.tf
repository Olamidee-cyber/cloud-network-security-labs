variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "iam-guardian"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule (e.g., rate(1 day) or cron)"
  type        = string
  default     = "rate(1 day)"
}

variable "results_prefix" {
  description = "S3 prefix for results"
  type        = string
  default     = "iam-guardian/"
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL (leave empty to disable alerts)"
  type        = string
  default     = ""
}

