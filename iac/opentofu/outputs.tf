output "vm_public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "ssh_command" {
  value = "ssh -i ${var.priv_key_path} ${var.user}@${azurerm_public_ip.public_ip.ip_address}"
}
