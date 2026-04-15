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

# ── Logic App: receives Azure Monitor alerts and forwards to Teams ──
resource "azurerm_logic_app_workflow" "alert_processor" {
  name                = "la-monitor-${var.environment}-alerts"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
}

resource "azurerm_logic_app_trigger_http_request" "alert" {
  name         = "When_an_HTTP_request_is_received"
  logic_app_id = azurerm_logic_app_workflow.alert_processor.id

  # Accept the Azure Monitor common alert schema (no strict schema enforcement)
  schema = "{}"
}
resource "azurerm_logic_app_action_http" "send_to_teams" {
  name         = "Send_to_Teams"
  logic_app_id = azurerm_logic_app_workflow.alert_processor.id
  method       = "POST"
  uri          = var.teams_webhook_url

  headers = {
    "Content-Type" = "application/json"
  }

  # Uses Logic App expression language — evaluated at runtime, not by Terraform.
  # triggerBody() returns the Azure Monitor common alert schema payload.
  # The Teams Workflow "Send webhook alerts to a channel" template requires
  # an Adaptive Card wrapped in a message envelope.
  # jsonencode() produces a valid JSON string; the @{...} expressions are
  # Logic App runtime expressions stored verbatim — Azure evaluates them when
  # the trigger fires, not at Terraform apply time.
  body = jsonencode({
    type = "message"
    attachments = [
      {
        contentType = "application/vnd.microsoft.card.adaptive"
        contentUrl  = ""
        content = {
          "$schema" = "http://adaptivecards.io/schemas/adaptive-card.json"
          type      = "AdaptiveCard"
          version   = "1.2"
          body = [
            {
              type   = "TextBlock"
              text   = "@{triggerBody()?['data']?['essentials']?['alertRule']}"
              weight = "Bolder"
              size   = "Medium"
              wrap   = true
            },
            {
              type  = "FactSet"
              facts = [
                { title = "Severity", value = "@{triggerBody()?['data']?['essentials']?['severity']}" },
                { title = "Status",   value = "@{triggerBody()?['data']?['essentials']?['monitorCondition']}" },
                { title = "Resource", value = "@{first(triggerBody()?['data']?['essentials']?['alertTargetIDs'])}" },
                { title = "Fired",    value = "@{triggerBody()?['data']?['essentials']?['firedDateTime']}" }
              ]
            },
            {
              type = "TextBlock"
              text = "@{triggerBody()?['data']?['essentials']?['description']}"
              wrap = true
              isSubtle = true
            }
          ]
        }
      }
    ]
  })
}
# ── Action Groups — one per severity tier, all routed to the Logic App ──
# Mapping: 0 = Critical, 1 = Error, 2 = Warning, 3 = Informational
locals {
  severity_labels = {
    0 = "critical"
    1 = "error"
    2 = "warning"
    3 = "informational"
  }
}

resource "azurerm_monitor_action_group" "by_severity" {
  for_each = local.severity_labels

  name                = "${var.action_group_prefix}-${var.environment}-${each.value}"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = substr("${var.action_group_prefix}${each.value}", 0, 12)
  enabled             = true

  webhook_receiver {
    name                    = "LogicApp-${each.value}"
    service_uri             = azurerm_logic_app_trigger_http_request.alert.callback_url
    use_common_alert_schema = true
  }
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
    action_group_id = azurerm_monitor_action_group.by_severity[tostring(each.value.severity)].id
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
    action_group_id = azurerm_monitor_action_group.by_severity[tostring(each.value.severity)].id
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

