output "agw" {
  value = azurerm_application_gateway.application_gateway
}

output "merged_ids" {
  value = [azurerm_application_gateway.application_gateway.id, azurerm_public_ip.pip.id, azurerm_key_vault.kv.id]
}