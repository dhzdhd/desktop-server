output "vm_public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "ssh_command" {
  value = "ssh -i ${var.priv_key_path} ${var.user}@${azurerm_public_ip.public_ip.ip_address}"
}

output "log" {
  value = ansible_playbook.local.temp_inventory_file
}


output "logg" {
  value = ansible_playbook.server.temp_inventory_file
}
