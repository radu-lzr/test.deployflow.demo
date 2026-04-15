terraform {
  backend "azurerm" {} # configured by Terrateam init args

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
# ── Resource Group ──
resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location
}

# ── Log Analytics Workspace ──
resource "azurerm_log_analytics_workspace" "monitoring" {
  name                = var.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ── Action Group (default) ──
resource "azurerm_monitor_action_group" "default" {
  name                = "${var.action_group_prefix}-${var.environment}-default"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = substr("${var.action_group_prefix}${var.environment}", 0, 12)
  enabled             = true
}

# ── Metric Alerts ──
resource "azurerm_monitor_metric_alert" "alerts" {
  for_each = var.metric_alerts
  name                = each.value.alert_name
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [each.value.resource_id]
  description         = each.value.description
  severity            = each.value.severity
  frequency           = each.value.evaluation_frequency
  window_size         = each.value.window_size
  auto_mitigate       = true
  enabled             = true

  criteria {
    metric_namespace = each.value.metric_namespace
    metric_name      = each.value.metric_name
    aggregation      = each.value.aggregation
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.default.id
  }
}

# ── Activity Log Alerts ──
resource "azurerm_monitor_activity_log_alert" "alerts" {
  for_each = var.activity_log_alerts
  location            = "Global"
  name                = each.value.alert_name
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [each.value.resource_id]
  description         = each.value.description
  enabled             = true

  criteria {
    category       = each.value.category
    operation_name = each.value.operation_name
    status         = each.value.status
  }

  action {
    action_group_id = azurerm_monitor_action_group.default.id
  }
}

# ── Diagnostic Settings ──
resource "azurerm_monitor_diagnostic_setting" "settings" {
  for_each = var.diagnostic_settings
  name                       = each.value.setting_name
  target_resource_id         = each.value.resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.monitoring.id

  dynamic "enabled_log" {
    for_each = each.value.log_category != "" ? [each.value.log_category] : []
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = each.value.metric_category != "" ? [each.value.metric_category] : []
    content {
      category = metric.value
      enabled  = true
    }
  }
}

