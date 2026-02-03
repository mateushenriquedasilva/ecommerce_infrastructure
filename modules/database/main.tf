# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name = "psql-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location = var.location
  version = "15"
  delegated_subnet_id = var.subnet_id
  private_dns_zone_id = var.private_dns_zone_id
  administrator_login = var.administrator_login
  administrator_password = var.administrator_password
  zone = "1"

  storage_mb = var.storage_mb
  sku_name = var.sku_name

  backup_retention_days = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  public_network_access_enabled = false

  high_availability {
    mode = var.environment == "prod" ? "ZoneRedundant" : "Disabled"
    standby_availability_zone = "prod" ? "2" : null
  }

  tags = var.tags
}

# Database within the PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server_database" "ecommerce" {
  name = "ecommerce_${var.environment}"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.UTF8"
  charset = "UTF8"
}

# Security Configuration
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value = "on"
}