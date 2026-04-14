resource "azurerm_virtual_network" "vnet" {
  location            = data.azurerm_resource_group.rg.location
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = var.aks_subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_subnet_cidr]
  service_endpoints    = var.subnet_service_endpoints
}

resource "azurerm_subnet" "postgresql" {
  name                 = var.postgresql_subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.postgresql_subnet_cidr]
  service_endpoints    = var.subnet_service_endpoints

  delegation {
    name = "postgresql-delegation"
    service_delegation { # Required
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "storage" {
  name                 = var.storage_subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.storage_subnet_cidr]
  service_endpoints    = var.subnet_service_endpoints
}

resource "azurerm_network_security_group" "aks" {
  location            = data.azurerm_resource_group.rg.location
  name                = "nsg-${var.aks_subnet_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "postgresql" {
  location            = data.azurerm_resource_group.rg.location
  name                = "nsg-${var.postgresql_subnet_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "storage" {
  location            = data.azurerm_resource_group.rg.location
  name                = "nsg-${var.storage_subnet_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  network_security_group_id = azurerm_network_security_group.aks.id
  subnet_id                 = azurerm_subnet.aks.id
}

resource "azurerm_subnet_network_security_group_association" "postgresql" {
  network_security_group_id = azurerm_network_security_group.postgresql.id
  subnet_id                 = azurerm_subnet.postgresql.id
}

resource "azurerm_subnet_network_security_group_association" "storage" {
  network_security_group_id = azurerm_network_security_group.storage.id
  subnet_id                 = azurerm_subnet.storage.id
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "${var.postgresql_server_name}.private.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags

  count = var.enable_private_endpoints ? 1 : 0

}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "postgresql-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql[0].name
  resource_group_name   = data.azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags

  count = var.enable_private_endpoints ? 1 : 0

}
