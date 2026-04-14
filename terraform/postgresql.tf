resource "azurerm_private_dns_zone" "postgresql_zone" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags

  # Computed attributes (read-only):
  # max_number_of_record_sets                             = (computed)
  # max_number_of_virtual_network_links                   = (computed)
  # max_number_of_virtual_network_links_with_registration = (computed)
  # number_of_record_sets                                 = (computed)
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql_zone_link" {
  name                  = "postgresql-zone-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql_zone.name
  resource_group_name   = data.azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_postgresql_flexible_server" "postgresql" {
  location                      = data.azurerm_resource_group.rg.location
  name                          = var.postgresql_server_name
  resource_group_name           = data.azurerm_resource_group.rg.name
  administrator_login           = var.postgresql_admin_username
  administrator_password        = var.postgresql_admin_password
  backup_retention_days         = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled  = var.postgresql_geo_redundant_backup
  public_network_access_enabled = true
  sku_name                      = var.postgresql_sku_name
  storage_mb                    = var.postgresql_storage_mb
  tags                          = var.tags
  version                       = var.postgresql_version
  zone                          = var.postgresql_zone

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  # Computed attributes (read-only):
  # fqdn = (computed)
}

resource "azurerm_postgresql_flexible_server_database" "odoo_db" {
  name      = var.postgresql_database_name
  server_id = azurerm_postgresql_flexible_server.postgresql.id
  charset   = var.postgresql_charset
  collation = var.postgresql_collation
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  end_ip_address   = "0.0.0.0"
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgresql.id
  start_ip_address = "0.0.0.0"

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  end_ip_address   = "255.255.255.255"
  name             = "AllowAKS"
  server_id        = azurerm_postgresql_flexible_server.postgresql.id
  start_ip_address = "0.0.0.0"

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }
}
