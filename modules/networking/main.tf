# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Create a virtual network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Create a subnet for API
resource "azurerm_subnet" "api" {
    name                = "subnet-api-${var.environment}"
    resource_group_name = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes    = var.subnet_api_prefix

    delegation {
      name = "app-service-delegation"
      service_delegation {
        name = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      } 
    }

    service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

# Create a subnet for Database
resource "azurerm_subnet" "database" {
    name                = "subnet-db-${var.environment}"
    resource_group_name = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes    = var.subnet_database_prefix

    delegation {
      name = "postgres-delegation"
      service_delegation {
        name = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }

    service_endpoints = ["Microsoft.Storage"]
}

# Create a subnet for Application Gateway
resource "azurerm_subnet" "agw" {
    name                = "subnet-agw-${var.environment}"
    resource_group_name = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes    = var.subnet_agw_prefix
}

# Create NSG for Api
resource "azurerm_network_security_group" "api" {
  name                = "nsg-api-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create NSG for Database
resource "azurerm_network_security_group" "database" {
  name                = "nsg-db-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "AllowPostgreSQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefixes      = var.subnet_api_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG to API subnet
resource "azurerm_subnet_network_security_group_association" "api" {
  subnet_id                = azurerm_subnet.api.id
  network_security_group_id = azurerm_network_security_group.api.id
}

# Associate NSG to Database subnet
resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

# Private DNS Zone for PostgreSQL - OBS
resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags               = var.tags
}

# Link VNet to Private DNS Zone - OBS
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "pdnslink-postgres-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags = var.tags
}