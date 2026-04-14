output "resource_group_name" {
  value       = data.azurerm_resource_group.rg.name
  description = "Resource group name"
}

output "resource_group_location" {
  value       = data.azurerm_resource_group.rg.location
  description = "Resource group location"
}

output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "AKS cluster name"
}

output "aks_cluster_id" {
  value       = azurerm_kubernetes_cluster.aks.id
  description = "AKS cluster ID"
}

output "aks_cluster_fqdn" {
  value       = azurerm_kubernetes_cluster.aks.fqdn
  description = "AKS cluster FQDN"
}

output "aks_kubeconfig_command" {
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
  description = "Command to retrieve the kubeconfig"
}

output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "VNET ID"
}

output "vnet_name" {
  value       = azurerm_virtual_network.vnet.name
  description = "VNET name"
}

output "aks_subnet_id" {
  value       = azurerm_subnet.aks.id
  description = "AKS subnet ID"
}

output "postgresql_server_name" {
  value       = azurerm_postgresql_flexible_server.postgresql.name
  description = "PostgreSQL server name"
}

output "postgresql_server_fqdn" {
  value       = azurerm_postgresql_flexible_server.postgresql.fqdn
  description = "PostgreSQL server FQDN"
}

output "postgresql_database_name" {
  value       = azurerm_postgresql_flexible_server_database.odoo_db.name
  description = "Odoo database name"
}

output "postgresql_admin_username" {
  value       = var.postgresql_admin_username
  description = "PostgreSQL admin username"
}

output "postgresql_connection_string" {
  value       = "postgresql://${var.postgresql_admin_username}@${azurerm_postgresql_flexible_server.postgresql.name}:${var.postgresql_admin_password}@${azurerm_postgresql_flexible_server.postgresql.fqdn}:5432/${azurerm_postgresql_flexible_server_database.odoo_db.name}"
  description = "PostgreSQL connection string"
  sensitive   = true
}

output "storage_account_name" {
  value       = azurerm_storage_account.storage.name
  description = "Storage Account name"
}

output "storage_account_primary_blob_endpoint" {
  value       = azurerm_storage_account.storage.primary_blob_endpoint
  description = "Storage Account Blob endpoint"
}

output "storage_container_name" {
  value       = azurerm_storage_container.odoo_filestore.name
  description = "Blob container name"
}

output "storage_account_primary_access_key" {
  value       = azurerm_storage_account.storage.primary_access_key
  description = "Storage Account primary access key"
  sensitive   = true
}
