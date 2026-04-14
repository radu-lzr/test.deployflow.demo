variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-deployflow-poc"
}

variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
  default     = "vnet-odoo"
}

variable "vnet_address_space" {
  description = "VNET address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_name" {
  description = "AKS subnet name"
  type        = string
  default     = "subnet-aks"
}

variable "aks_subnet_cidr" {
  description = "AKS subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "postgresql_subnet_name" {
  description = "PostgreSQL subnet name"
  type        = string
  default     = "subnet-postgresql"
}

variable "postgresql_subnet_cidr" {
  description = "PostgreSQL subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "storage_subnet_name" {
  description = "Storage Account subnet name"
  type        = string
  default     = "subnet-storage"
}

variable "storage_subnet_cidr" {
  description = "Storage subnet CIDR"
  type        = string
  default     = "10.0.3.0/24"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "aks-odoo"
}

variable "aks_dns_prefix" {
  description = "AKS DNS prefix"
  type        = string
  default     = "odoo"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_node_pool_min_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "aks_node_pool_max_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "aks_network_plugin" {
  description = "AKS network plugin (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "aks_network_policy" {
  description = "Kubernetes network policy (azure or calico)"
  type        = string
  default     = "azure"
}

variable "postgresql_server_name" {
  description = "PostgreSQL server name"
  type        = string
  default     = "psql-odoo"
}

variable "postgresql_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "psqladmin"
}

variable "postgresql_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "postgresql_sku_name" {
  description = "SKU PostgreSQL (ex: B_Standard_B1ms, GP_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 32768
}

variable "postgresql_backup_retention_days" {
  description = "Backup retention days"
  type        = number
  default     = 7
}

variable "postgresql_geo_redundant_backup" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "postgresql_database_name" {
  description = "Odoo database name"
  type        = string
  default     = "odoo_db"
}

variable "storage_account_name" {
  description = "Storage Account name (must be globally unique, 3-24 characters, lowercase letters and digits)"
  type        = string
}

variable "storage_account_tier" {
  description = "Storage Account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "Replication type (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
}

variable "storage_container_name" {
  description = "Blob container name for Odoo files"
  type        = string
  default     = "odoo-filestore"
}

variable "odoo_storage_sp_object_id" {
  description = "Object ID of the pre-created Service Principal for Odoo storage access (used for role assignment)"
  type        = string
}

variable "enable_private_endpoints" {
  description = "Enable Private Endpoints for all services"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "Allowed IP ranges for access (if no Private Endpoint)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    Project     = "StackOdoo"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

variable "aks_os_disk_size_gb" {
  description = "OS disk size in GB for AKS nodes"
  type        = number
  default     = 50
}

variable "aks_service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "IP address for the Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

variable "aks_load_balancer_sku" {
  description = "SKU of the Load Balancer used by AKS"
  type        = string
  default     = "standard"
}

variable "subnet_service_endpoints" {
  description = "List of service endpoints to enable on subnets"
  type        = list(string)
  default     = ["Microsoft.Storage"]
}

variable "nsg_security_rule_https_priority" {
  description = "Priority for the HTTPS security rule"
  type        = number
  default     = 100
}

variable "nsg_security_rule_http_priority" {
  description = "Priority for the HTTP security rule"
  type        = number
  default     = 105
}

variable "postgresql_zone" {
  description = "Availability zone for PostgreSQL"
  type        = string
  default     = "1"
}

variable "postgresql_charset" {
  description = "Charset for the PostgreSQL database"
  type        = string
  default     = "UTF8"
}

variable "postgresql_collation" {
  description = "Collation for the PostgreSQL database"
  type        = string
  default     = "en_US.utf8"
}

variable "storage_retention_days" {
  description = "Number of days to retain deleted blobs"
  type        = number
  default     = 7
}

variable "storage_lifecycle_cool_days" {
  description = "Days after modification to move blobs to cool tier"
  type        = number
  default     = 30
}

variable "storage_lifecycle_archive_days" {
  description = "Days after modification to move blobs to archive tier"
  type        = number
  default     = 90
}
