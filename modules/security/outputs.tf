output "key_vault_id" {
  description = "Key Vault ID"
  value = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Key Vault Name"
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}