resource "azurerm_kubernetes_cluster" "aks" {
  location            = data.azurerm_resource_group.rg.location
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.aks_kubernetes_version
  tags                = var.tags

  default_node_pool { # Required
    name                        = "default"
    vm_size                     = var.aks_node_vm_size
    vnet_subnet_id              = azurerm_subnet.aks.id
    auto_scaling_enabled        = true
    min_count                   = var.aks_node_pool_min_count
    max_count                   = var.aks_node_pool_max_count
    os_disk_size_gb             = var.aks_os_disk_size_gb
    temporary_name_for_rotation = "temppool"
    node_labels                 = {
      "workload" = "odoo"
    }
    tags                        = var.tags
  }
  identity {
    type = "SystemAssigned"
  }
  network_profile {
    network_plugin    = var.aks_network_plugin
    network_policy    = var.aks_network_policy
    service_cidr      = var.aks_service_cidr
    dns_service_ip    = var.aks_dns_service_ip
    load_balancer_sku = var.aks_load_balancer_sku
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings,
    ]
  }

}
