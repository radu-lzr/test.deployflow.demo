resource "azurerm_storage_account" "storage" {
  account_replication_type        = var.storage_account_replication_type
  account_tier                    = var.storage_account_tier
  location                        = data.azurerm_resource_group.rg.location
  name                            = var.storage_account_name
  resource_group_name             = data.azurerm_resource_group.rg.name
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
  tags                            = var.tags

  blob_properties {
    container_delete_retention_policy {
      days = var.storage_retention_days
    }
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["PUT", "GET", "HEAD", "OPTIONS"]
      allowed_origins    = ["*"]
      exposed_headers    = ["x-ms-meta-*", "x-ms-request-id", "x-ms-version", "etag", "content-length", "content-type"]
      max_age_in_seconds = 3600
    }
    delete_retention_policy {
      days = var.storage_retention_days
    }
  }
  network_rules {
    default_action             = "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [
      azurerm_subnet.aks.id,
      azurerm_subnet.storage.id
    ]
    ip_rules                   = var.allowed_ip_ranges
  }
}

resource "azurerm_storage_container" "odoo_filestore" {
  name                  = var.storage_container_name
  container_access_type = "private"
  storage_account_id    = azurerm_storage_account.storage.id
}

resource "azurerm_role_assignment" "odoo_storage_sp" {
  principal_id         = var.odoo_storage_sp_object_id
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.storage.id

  rule {
    enabled = true
    name    = "deleteOldVersions"
    actions { # Required
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.storage_lifecycle_cool_days
        tier_to_archive_after_days_since_modification_greater_than = var.storage_lifecycle_archive_days
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 30
      }
    }
    filters { # Required
      blob_types = ["blockBlob"]
    }
  }
}

resource "azurerm_private_endpoint" "storage" {
  location            = data.azurerm_resource_group.rg.location
  name                = "pe-${var.storage_account_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.storage.id
  tags                = var.tags

  private_dns_zone_group {
    name                 = "pdz-group-storage"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage[0].id]
  }
  private_service_connection { # Required
    is_manual_connection           = false
    name                           = "psc-${var.storage_account_name}"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
  }

  count = var.enable_private_endpoints ? 1 : 0

}

resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags

  count = var.enable_private_endpoints ? 1 : 0

}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "storage-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.storage[0].name
  resource_group_name   = data.azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags

  count = var.enable_private_endpoints ? 1 : 0

}
