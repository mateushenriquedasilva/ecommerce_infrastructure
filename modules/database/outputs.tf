output "server_id" {
  description = "Postgres server ID"
  value = azurerm_postgresql_flexible_server.main.id
}

output "server_fqdn" {
  description = "Postgres server fully qualified domain name"
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
    description = "Database Name"
  value = azurerm_postgresql_flexible_server_database.ecommerce.name
}

output "administrator_login" {
  description = "Postgres server administrator login"
  value = azurerm_postgresql_flexible_server.main.administrator_login
  sensitive = true
}