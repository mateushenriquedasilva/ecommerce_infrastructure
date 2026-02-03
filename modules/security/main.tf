data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
    name                        = "kv-${var.project_name}-${var.environment}"
    location                    = var.location
    resource_group_name         = var.resource_group_name
    enabled_for_disk_encryption  = true
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    soft_delete_retention_days         = 7
    purge_protection_enabled    = var.environment == "prod" ? true : false
    sku_name                    = "standard"

    public_network_access_enabled = false

    network_acls {
      bypass = "AzureServices"
      default_action = "Deny"
    }

    tags = var.tags
}

# Key Vault Access Policy for current user
resource "azurerm_key_vault_access_policy" "terrafomr" {
    key_vault_id = azurerm_key_vault.main.id
    tenant_id    = data.azurerm_client_config.current.tenant_id
    object_id    = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]

    certificate_permissions = [
        "Get",
        "List",
        "Create",
        "Delete",
        "Purge",
    ]

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Purge",
    ]
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
    name                = "pe-kv-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name
    subnet_id           = var.subnet_id

    private_service_connection {
        name                           = "psc-kv-${var.environment}"
        private_connection_resource_id = azurerm_key_vault.main.id
        is_manual_connection           = false
        subresource_names              = ["vault"]
    }

    private_dns_zone_group {
      name = "pdnszg-kv-${var.environment}"
      private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
    }

    tags = var.tags
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
    name                = "privatelink.vaultcore.azure.net"
    resource_group_name = var.resource_group_name
    tags                = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
    name                  = "pdnslink-kv-${var.environment}"
    resource_group_name   = var.resource_group_name
    private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
    virtual_network_id    = var.vnet_id
    tags = var.tags
}