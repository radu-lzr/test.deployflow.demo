environment = "poc"
location    = "northeurope"

resource_group_name          = "rg-monitor-deployflow-poc"
log_analytics_workspace_name = "law-monitor-deployflow-poc"
action_group_prefix          = "ag"

metric_alerts = {
  "stdeployflowdemotest-usedcapacity-0" = {
    alert_name           = "stdeployflowdemotest-UsedCapacity-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "UsedCapacity"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 80
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: UsedCapacity on stdeployflowdemotest"
  }
  "stdeployflowdemotest-usedcapacity-1" = {
    alert_name           = "stdeployflowdemotest-UsedCapacity-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "UsedCapacity"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 80
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: UsedCapacity on stdeployflowdemotest"
  }
  "stdeployflowdemotest-usedcapacity-2" = {
    alert_name           = "stdeployflowdemotest-UsedCapacity-2"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "UsedCapacity"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 80
    severity             = 2
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: UsedCapacity on stdeployflowdemotest"
  }
  "stdeployflowdemotest-availability-0" = {
    alert_name           = "stdeployflowdemotest-Availability-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "Availability"
    operator             = "LessThan"
    aggregation          = "Average"
    threshold            = 99
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: Availability on stdeployflowdemotest"
  }
  "aks-odoo-cluster_autoscaler_cluster_safe_to_autoscale-0" = {
    alert_name           = "aks-odoo-cluster_autoscaler_cluster_safe_to_autoscale-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "cluster_autoscaler_cluster_safe_to_autoscale"
    operator             = "LessThan"
    aggregation          = "Average"
    threshold            = 1
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: cluster_autoscaler_cluster_safe_to_autoscale on aks-odoo"
  }
  "aks-odoo-kube_pod_status_phase-0" = {
    alert_name           = "aks-odoo-kube_pod_status_phase-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "kube_pod_status_phase"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 1
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: kube_pod_status_phase on aks-odoo"
  }
  "aks-odoo-node_cpu_usage_percentage-0" = {
    alert_name           = "aks-odoo-node_cpu_usage_percentage-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_cpu_usage_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 95
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_cpu_usage_percentage on aks-odoo"
  }
  "aks-odoo-node_cpu_usage_percentage-1" = {
    alert_name           = "aks-odoo-node_cpu_usage_percentage-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_cpu_usage_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 90
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_cpu_usage_percentage on aks-odoo"
  }
  "aks-odoo-node_cpu_usage_percentage-2" = {
    alert_name           = "aks-odoo-node_cpu_usage_percentage-2"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_cpu_usage_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 85
    severity             = 2
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_cpu_usage_percentage on aks-odoo"
  }
  "aks-odoo-node_memory_working_set_percentage-0" = {
    alert_name           = "aks-odoo-node_memory_working_set_percentage-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_memory_working_set_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 120
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_memory_working_set_percentage on aks-odoo"
  }
  "aks-odoo-node_memory_working_set_percentage-1" = {
    alert_name           = "aks-odoo-node_memory_working_set_percentage-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_memory_working_set_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 110
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_memory_working_set_percentage on aks-odoo"
  }
  "aks-odoo-node_memory_working_set_percentage-2" = {
    alert_name           = "aks-odoo-node_memory_working_set_percentage-2"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_memory_working_set_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 100
    severity             = 2
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_memory_working_set_percentage on aks-odoo"
  }
  "aks-odoo-kube_node_status_condition-1" = {
    alert_name           = "aks-odoo-kube_node_status_condition-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "kube_node_status_condition"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 1
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: kube_node_status_condition on aks-odoo"
  }
  "aks-odoo-node_disk_usage_percentage-0" = {
    alert_name           = "aks-odoo-node_disk_usage_percentage-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_disk_usage_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 95
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_disk_usage_percentage on aks-odoo"
  }
  "aks-odoo-node_disk_usage_percentage-1" = {
    alert_name           = "aks-odoo-node_disk_usage_percentage-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_disk_usage_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 90
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_disk_usage_percentage on aks-odoo"
  }
  "aks-odoo-node_disk_usage_percentage-2" = {
    alert_name           = "aks-odoo-node_disk_usage_percentage-2"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_disk_usage_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 85
    severity             = 2
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_disk_usage_percentage on aks-odoo"
  }
  "aks-odoo-cluster_autoscaler_unneeded_nodes_count-1" = {
    alert_name           = "aks-odoo-cluster_autoscaler_unneeded_nodes_count-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "cluster_autoscaler_unneeded_nodes_count"
    operator             = "GreaterThan"
    aggregation          = "Average"
    threshold            = 1
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: cluster_autoscaler_unneeded_nodes_count on aks-odoo"
  }
  "aks-odoo-node_memory_rss_percentage-0" = {
    alert_name           = "aks-odoo-node_memory_rss_percentage-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_memory_rss_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 95
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_memory_rss_percentage on aks-odoo"
  }
  "aks-odoo-node_memory_rss_percentage-1" = {
    alert_name           = "aks-odoo-node_memory_rss_percentage-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_memory_rss_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 90
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_memory_rss_percentage on aks-odoo"
  }
  "aks-odoo-node_memory_rss_percentage-2" = {
    alert_name           = "aks-odoo-node_memory_rss_percentage-2"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    metric_namespace     = "microsoft.containerservice/managedclusters"
    metric_name          = "node_memory_rss_percentage"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 85
    severity             = 2
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: node_memory_rss_percentage on aks-odoo"
  }
  "stdemodeployflowabc-usedcapacity-0" = {
    alert_name           = "stdemodeployflowabc-UsedCapacity-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "UsedCapacity"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 80
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: UsedCapacity on stdemodeployflowabc"
  }
  "stdemodeployflowabc-usedcapacity-1" = {
    alert_name           = "stdemodeployflowabc-UsedCapacity-1"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "UsedCapacity"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 80
    severity             = 1
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: UsedCapacity on stdemodeployflowabc"
  }
  "stdemodeployflowabc-usedcapacity-2" = {
    alert_name           = "stdemodeployflowabc-UsedCapacity-2"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "UsedCapacity"
    operator             = "GreaterThanOrEqual"
    aggregation          = "Average"
    threshold            = 80
    severity             = 2
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: UsedCapacity on stdemodeployflowabc"
  }
  "stdemodeployflowabc-availability-0" = {
    alert_name           = "stdemodeployflowabc-Availability-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    metric_namespace     = "microsoft.storage/storageaccounts"
    metric_name          = "Availability"
    operator             = "LessThan"
    aggregation          = "Average"
    threshold            = 99
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: Availability on stdemodeployflowabc"
  }
  "kubernetes-vipavailability-0" = {
    alert_name           = "kubernetes-VipAvailability-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/loadBalancers/kubernetes"
    metric_namespace     = "microsoft.network/loadbalancers"
    metric_name          = "VipAvailability"
    operator             = "LessThan"
    aggregation          = "Average"
    threshold            = 75
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: VipAvailability on kubernetes"
  }
  "kubernetes-dipavailability-0" = {
    alert_name           = "kubernetes-DipAvailability-0"
    resource_id          = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/loadBalancers/kubernetes"
    metric_namespace     = "microsoft.network/loadbalancers"
    metric_name          = "DipAvailability"
    operator             = "LessThan"
    aggregation          = "Average"
    threshold            = 100
    severity             = 0
    evaluation_frequency = "PT5M"
    window_size          = "PT5M"
    description          = "Metric alert: DipAvailability on kubernetes"
  }
}

activity_log_alerts = {
  "stdeployflowdemotest-write-success" = {
    alert_name     = "stdeployflowdemotest-write-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    operation_name = "Microsoft.Storage/storageAccounts/write"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Storage account created or updated - Success"
  }
  "stdeployflowdemotest-write-failure" = {
    alert_name     = "stdeployflowdemotest-write-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    operation_name = "Microsoft.Storage/storageAccounts/write"
    category       = "Administrative"
    status         = "Failed"
    description    = "Storage account created or updated - Failure"
  }
  "stdeployflowdemotest-action-success" = {
    alert_name     = "stdeployflowdemotest-action-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    operation_name = "Microsoft.Storage/storageAccounts/listKeys/action"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Storage account keys listed - Success"
  }
  "stdeployflowdemotest-action-failure" = {
    alert_name     = "stdeployflowdemotest-action-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    operation_name = "Microsoft.Storage/storageAccounts/regeneratekey/action"
    category       = "Administrative"
    status         = "Failed"
    description    = "Storage account key regenerated - Failure"
  }
  "stdeployflowdemotest-delete-success" = {
    alert_name     = "stdeployflowdemotest-delete-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    operation_name = "Microsoft.Storage/storageAccounts/delete"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Storage account deleted - Success"
  }
  "stdeployflowdemotest-delete-failure" = {
    alert_name     = "stdeployflowdemotest-delete-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    operation_name = "Microsoft.Storage/storageAccounts/delete"
    category       = "Administrative"
    status         = "Failed"
    description    = "Storage account deleted - Failure"
  }
  "vnet-odoo-write-success" = {
    alert_name     = "vnet-odoo-write-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Network/virtualNetworks/vnet-odoo"
    operation_name = "Microsoft.Network/virtualNetworks/write"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Virtual network created or updated - Success"
  }
  "vnet-odoo-write-failure" = {
    alert_name     = "vnet-odoo-write-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Network/virtualNetworks/vnet-odoo"
    operation_name = "Microsoft.Network/virtualNetworks/write"
    category       = "Administrative"
    status         = "Failed"
    description    = "Virtual network created or updated - Failure"
  }
  "vnet-odoo-delete-success" = {
    alert_name     = "vnet-odoo-delete-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Network/virtualNetworks/vnet-odoo"
    operation_name = "Microsoft.Network/virtualNetworks/delete"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Virtual network deleted - Success"
  }
  "vnet-odoo-delete-failure" = {
    alert_name     = "vnet-odoo-delete-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Network/virtualNetworks/vnet-odoo"
    operation_name = "Microsoft.Network/virtualNetworks/delete"
    category       = "Administrative"
    status         = "Failed"
    description    = "Virtual network deleted - Failure"
  }
  "aks-odoo-action-failure" = {
    alert_name     = "aks-odoo-action-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    operation_name = "Microsoft.ContainerService/managedClusters/stop/action"
    category       = "Administrative"
    status         = "Failed"
    description    = "AKS cluster stop failed - Failure"
  }
  "aks-odoo-delete-success" = {
    alert_name     = "aks-odoo-delete-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    operation_name = "Microsoft.ContainerService/managedClusters/delete"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "AKS cluster deleted - Success"
  }
  "aks-odoo-delete-failure" = {
    alert_name     = "aks-odoo-delete-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    operation_name = "Microsoft.ContainerService/managedClusters/delete"
    category       = "Administrative"
    status         = "Failed"
    description    = "AKS cluster deleted - Failure"
  }
  "aks-odoo-write-success" = {
    alert_name     = "aks-odoo-write-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    operation_name = "Microsoft.ContainerService/managedClusters/write"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "AKS cluster created or updated - Success"
  }
  "aks-odoo-write-failure" = {
    alert_name     = "aks-odoo-write-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    operation_name = "Microsoft.ContainerService/managedClusters/write"
    category       = "Administrative"
    status         = "Failed"
    description    = "AKS cluster created or updated - Failure"
  }
  "stdemodeployflowabc-write-success" = {
    alert_name     = "stdemodeployflowabc-write-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    operation_name = "Microsoft.Storage/storageAccounts/write"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Storage account created or updated - Success"
  }
  "stdemodeployflowabc-write-failure" = {
    alert_name     = "stdemodeployflowabc-write-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    operation_name = "Microsoft.Storage/storageAccounts/write"
    category       = "Administrative"
    status         = "Failed"
    description    = "Storage account created or updated - Failure"
  }
  "stdemodeployflowabc-action-success" = {
    alert_name     = "stdemodeployflowabc-action-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    operation_name = "Microsoft.Storage/storageAccounts/listKeys/action"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Storage account keys listed - Success"
  }
  "stdemodeployflowabc-action-failure" = {
    alert_name     = "stdemodeployflowabc-action-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    operation_name = "Microsoft.Storage/storageAccounts/regeneratekey/action"
    category       = "Administrative"
    status         = "Failed"
    description    = "Storage account key regenerated - Failure"
  }
  "stdemodeployflowabc-delete-success" = {
    alert_name     = "stdemodeployflowabc-delete-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    operation_name = "Microsoft.Storage/storageAccounts/delete"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Storage account deleted - Success"
  }
  "stdemodeployflowabc-delete-failure" = {
    alert_name     = "stdemodeployflowabc-delete-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    operation_name = "Microsoft.Storage/storageAccounts/delete"
    category       = "Administrative"
    status         = "Failed"
    description    = "Storage account deleted - Failure"
  }
  "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-delete-success" = {
    alert_name     = "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-delete-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/publicIPAddresses/4db73ea6-fcc8-4402-92c6-0562dd72a5e5"
    operation_name = "Microsoft.Network/publicIPAddresses/delete"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Public IP deleted - Success"
  }
  "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-delete-failure" = {
    alert_name     = "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-delete-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/publicIPAddresses/4db73ea6-fcc8-4402-92c6-0562dd72a5e5"
    operation_name = "Microsoft.Network/publicIPAddresses/delete"
    category       = "Administrative"
    status         = "Failed"
    description    = "Public IP deleted - Failure"
  }
  "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-write-success" = {
    alert_name     = "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-write-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/publicIPAddresses/4db73ea6-fcc8-4402-92c6-0562dd72a5e5"
    operation_name = "Microsoft.Network/publicIPAddresses/write"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Public IP created or updated - Success"
  }
  "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-write-failure" = {
    alert_name     = "4db73ea6-fcc8-4402-92c6-0562dd72a5e5-write-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/publicIPAddresses/4db73ea6-fcc8-4402-92c6-0562dd72a5e5"
    operation_name = "Microsoft.Network/publicIPAddresses/write"
    category       = "Administrative"
    status         = "Failed"
    description    = "Public IP created or updated - Failure"
  }
  "kubernetes-write-success" = {
    alert_name     = "kubernetes-write-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/loadBalancers/kubernetes"
    operation_name = "Microsoft.Network/loadBalancers/write"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Load balancer created or updated - Success"
  }
  "kubernetes-write-failure" = {
    alert_name     = "kubernetes-write-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/loadBalancers/kubernetes"
    operation_name = "Microsoft.Network/loadBalancers/write"
    category       = "Administrative"
    status         = "Failed"
    description    = "Load balancer created or updated - Failure"
  }
  "kubernetes-delete-success" = {
    alert_name     = "kubernetes-delete-Success"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/loadBalancers/kubernetes"
    operation_name = "Microsoft.Network/loadBalancers/delete"
    category       = "Administrative"
    status         = "Succeeded"
    description    = "Load balancer deleted - Success"
  }
  "kubernetes-delete-failure" = {
    alert_name     = "kubernetes-delete-Failure"
    resource_id    = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/MC_rg-deployflow-poc_aks-odoo_northeurope/providers/Microsoft.Network/loadBalancers/kubernetes"
    operation_name = "Microsoft.Network/loadBalancers/delete"
    category       = "Administrative"
    status         = "Failed"
    description    = "Load balancer deleted - Failure"
  }
}

diagnostic_settings = {
  "deployflow-stdeployflowdemotest-storagedelete" = {
    setting_name    = "deployflow-stdeployflowdemotest-storagedelete"
    resource_id     = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/NetworkWatcherRG/providers/Microsoft.Storage/storageAccounts/stdeployflowdemotest"
    log_category    = "StorageDelete"
    metric_category = ""
  }
  "deployflow-aks-odoo-kube-audit" = {
    setting_name    = "deployflow-aks-odoo-kube-audit"
    resource_id     = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    log_category    = "kube-audit"
    metric_category = ""
  }
  "deployflow-aks-odoo-kube-audit-admin" = {
    setting_name    = "deployflow-aks-odoo-kube-audit-admin"
    resource_id     = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    log_category    = "kube-audit-admin"
    metric_category = ""
  }
  "deployflow-aks-odoo-kube-apiserver" = {
    setting_name    = "deployflow-aks-odoo-kube-apiserver"
    resource_id     = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    log_category    = "kube-apiserver"
    metric_category = ""
  }
  "deployflow-aks-odoo-kube-controller-manager" = {
    setting_name    = "deployflow-aks-odoo-kube-controller-manager"
    resource_id     = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.ContainerService/managedClusters/aks-odoo"
    log_category    = "kube-controller-manager"
    metric_category = ""
  }
  "deployflow-stdemodeployflowabc-storagedelete" = {
    setting_name    = "deployflow-stdemodeployflowabc-storagedelete"
    resource_id     = "/subscriptions/012ff211-66c6-4b69-a410-88b8ac90045d/resourceGroups/rg-deployflow-poc/providers/Microsoft.Storage/storageAccounts/stdemodeployflowabc"
    log_category    = "StorageDelete"
    metric_category = ""
  }
}
