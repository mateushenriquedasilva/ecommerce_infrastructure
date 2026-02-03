output "resource_group_name" {
  description = "Resource Group Name"
  value = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Resource Group Location"
  value = azurerm_resource_group.main.location
}

output "vnet_id" {
  description = "Virtual Network ID"
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network Name"
  value = azurerm_virtual_network.main.name
}

output "subnet_api_id" {
  description = "Subnet API ID"
  value = azurerm_subnet.api.id
}

output "subnet_database_id" {
  description = "Subnet Database ID"
  value = azurerm_subnet.database.id
}

output "subnet_agw_id" {
  description = "Subnet AGW ID"
  value = azurerm_subnet.agw.id
}

output "private_dns_zone_id" {
  description = "Private DNS Zone ID"
  value = azurerm_private_dns_zone.main.id
}

output "nsg_api_id" {
  description = "Network Security Group API ID"
  value = azurerm_network_security_group.api.id
}

output "nsg_database_id" {
  description = "Network Security Group Database ID"
  value = azurerm_network_security_group.database.id
}