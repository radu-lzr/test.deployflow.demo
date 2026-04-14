data "azurerm_resource_group" "rg" {
  name = var.resource_group_name

  # Computed attributes (read-only):
  # location   = (computed)
  # managed_by = (computed)
  # tags       = (computed)
}
