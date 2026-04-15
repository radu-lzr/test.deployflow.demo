variable "environment" {
  description = "Deployment environment (dev, prod, etc.)"
  type        = string
}

variable "location" {
  description = "Azure region for resource group and workspace"
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Resource group that owns monitoring resources"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  type        = string
}

variable "action_group_prefix" {
  description = "Prefix for action group names (e.g. 'ag')"
  type        = string
  default     = "ag"
}

variable "teams_webhook_url" {
  description = "Microsoft Teams incoming webhook URL — injected by Terrateam from {ENV}_TEAMS_WEBHOOK_URL secret"
  type        = string
  sensitive   = true
}

variable "metric_alerts" {
  description = "Map of metric alert definitions (auto-generated from matrix)"
  type = map(object({
    alert_name           = string
    resource_id          = string
    metric_namespace     = string
    metric_name          = string
    operator             = string
    aggregation          = string
    threshold            = number
    severity             = number
    evaluation_frequency = string
    window_size          = string
    description          = string
  }))
  default = {}
}

variable "activity_log_alerts" {
  description = "Map of activity log alert definitions (auto-generated from matrix)"
  type = map(object({
    alert_name     = string
    resource_id    = string
    operation_name = string
    category       = string
    status         = string
    description    = string
    severity       = number
  }))
  default = {}
}

variable "diagnostic_settings" {
  description = "Map of diagnostic settings (auto-generated from matrix)"
  type = map(object({
    setting_name    = string
    resource_id     = string
    log_category    = string
    metric_category = string
  }))
  default = {}
}