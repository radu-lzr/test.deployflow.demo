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

  # Computed attributes (read-only):
  # primary_access_key                 = (computed)
  # primary_blob_connection_string     = (computed)
  # primary_blob_endpoint              = (computed)
  # primary_blob_host                  = (computed)
  # primary_blob_internet_endpoint     = (computed)
  # primary_blob_internet_host         = (computed)
  # primary_blob_microsoft_endpoint    = (computed)
  # primary_blob_microsoft_host        = (computed)
  # primary_connection_string          = (computed)
  # primary_dfs_endpoint               = (computed)
  # primary_dfs_host                   = (computed)
  # primary_dfs_internet_endpoint      = (computed)
  # primary_dfs_internet_host          = (computed)
  # primary_dfs_microsoft_endpoint     = (computed)
  # primary_dfs_microsoft_host         = (computed)
  # primary_file_endpoint              = (computed)
  # primary_file_host                  = (computed)
  # primary_file_internet_endpoint     = (computed)
  # primary_file_internet_host         = (computed)
  # primary_file_microsoft_endpoint    = (computed)
  # primary_file_microsoft_host        = (computed)
  # primary_location                   = (computed)
  # primary_queue_endpoint             = (computed)
  # primary_queue_host                 = (computed)
  # primary_queue_microsoft_endpoint   = (computed)
  # primary_queue_microsoft_host       = (computed)
  # primary_table_endpoint             = (computed)
  # primary_table_host                 = (computed)
  # primary_table_microsoft_endpoint   = (computed)
  # primary_table_microsoft_host       = (computed)
  # primary_web_endpoint               = (computed)
  # primary_web_host                   = (computed)
  # primary_web_internet_endpoint      = (computed)
  # primary_web_internet_host          = (computed)
  # primary_web_microsoft_endpoint     = (computed)
  # primary_web_microsoft_host         = (computed)
  # secondary_access_key               = (computed)
  # secondary_blob_connection_string   = (computed)
  # secondary_blob_endpoint            = (computed)
  # secondary_blob_host                = (computed)
  # secondary_blob_internet_endpoint   = (computed)
  # secondary_blob_internet_host       = (computed)
  # secondary_blob_microsoft_endpoint  = (computed)
  # secondary_blob_microsoft_host      = (computed)
  # secondary_connection_string        = (computed)
  # secondary_dfs_endpoint             = (computed)
  # secondary_dfs_host                 = (computed)
  # secondary_dfs_internet_endpoint    = (computed)
  # secondary_dfs_internet_host        = (computed)
  # secondary_dfs_microsoft_endpoint   = (computed)
  # secondary_dfs_microsoft_host       = (computed)
  # secondary_file_endpoint            = (computed)
  # secondary_file_host                = (computed)
  # secondary_file_internet_endpoint   = (computed)
  # secondary_file_internet_host       = (computed)
  # secondary_file_microsoft_endpoint  = (computed)
  # secondary_file_microsoft_host      = (computed)
  # secondary_location                 = (computed)
  # secondary_queue_endpoint           = (computed)
  # secondary_queue_host               = (computed)
  # secondary_queue_microsoft_endpoint = (computed)
  # secondary_queue_microsoft_host     = (computed)
  # secondary_table_endpoint           = (computed)
  # secondary_table_host               = (computed)
  # secondary_table_microsoft_endpoint = (computed)
  # secondary_table_microsoft_host     = (computed)
  # secondary_web_endpoint             = (computed)
  # secondary_web_host                 = (computed)
  # secondary_web_internet_endpoint    = (computed)
  # secondary_web_internet_host        = (computed)
  # secondary_web_microsoft_endpoint   = (computed)
  # secondary_web_microsoft_host       = (computed)
}

resource "azurerm_storage_container" "odoo_filestore" {
  name                  = var.storage_container_name
  container_access_type = "private"
  storage_account_id    = azurerm_storage_account.storage.id

  # Computed attributes (read-only):
  # has_immutability_policy = (computed)
  # has_legal_hold          = (computed)
  # resource_manager_id     = (computed)
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

    # Computed attributes (read-only):
    # id = (computed)
  }
  private_service_connection { # Required
    is_manual_connection           = false
    name                           = "psc-${var.storage_account_name}"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]

    # Computed attributes (read-only):
    # private_ip_address = (computed)
  }

  # Computed attributes (read-only):
  # custom_dns_configs       = (computed)
  # network_interface        = (computed)
  # private_dns_zone_configs = (computed)

  count = var.enable_private_endpoints ? 1 : 0

}

resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags

  # Computed attributes (read-only):
  # max_number_of_record_sets                             = (computed)
  # max_number_of_virtual_network_links                   = (computed)
  # max_number_of_virtual_network_links_with_registration = (computed)
  # number_of_record_sets                                 = (computed)

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
