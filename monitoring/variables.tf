variable "environment" {
  description = "Deployment environment (dev, prod, etc.)"
  type        = string
}

variable "location" {
  description = "Azure region for monitoring resources"
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Name of the monitoring resource group"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
}

variable "action_group_prefix" {
  description = "Prefix for action group names"
  type        = string
  default     = "ag"
}

variable "monitored_resources" {
  description = "Map of resource keys to Azure resource IDs, populated from discovery workflow artifacts"
  type        = map(string)
  default     = {}
}
