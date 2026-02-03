variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type = string
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type = string
}

variable "location" {
  description = "Location for resources"
  type = string
}

variable "subnet_id" {
  description = "Subnet ID for Database"
  type = string
}

variable "private_dns_zone_id" {
  description = "Private DNS Zone ID for Database"
  type = string
}

variable "administrator_login" {
  description = "Administrator login for Database"
  type = string
}

variable "administrator_password" {
  description = "Administrator password for Database"
  type = string
}

variable "sku_name" {
  description = "SKU name for Database"
  type = string
  default     = "B_Standard_B1ms" # Para dev/staging. Prod: GP_Standard_D2s_v3
}

variable "storage_mb" {
  description = "Storage size in MB for Database"
  type        = number
  default     = 32768 # 32GB
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup for Database"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}