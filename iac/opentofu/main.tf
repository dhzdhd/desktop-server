terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.39"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1"
    }
  }
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
  disable_correlation_request_id  = true
  disable_terraform_partner_id    = true
}

resource "azurerm_resource_group" "resource_group" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "virt_network" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-internal-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virt_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.prefix}-public-ip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  ip_version          = "IPv4"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  size                = var.size
  admin_username      = "dhzdhd"
  zone                = var.zone
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "dhzdhd"
    public_key = file(var.pub_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "cloudflare_dns_record" "www" {
  zone_id = "137d6017a29b7feb91abcc9840b375b3"
  name    = "dhzdhd.dev"
  ttl     = 3600
  type    = "A"
  content = azurerm_public_ip.public_ip.ip_address
  proxied = false
}

resource "ansible_group" "local" {
  name      = "local"
  children  = []
  variables = {}
}

resource "ansible_group" "server" {
  name      = "server"
  children  = []
  variables = {}
}

resource "ansible_host" "local" {
  name   = "local"
  groups = [ansible_group.local.name]
  variables = {
    ansible_connection = "local"
    # ansible_host       = "localhost"
  }
}

resource "ansible_host" "server" {
  name   = "server"
  groups = [ansible_group.server.name]
  variables = {
    ansible_user                 = var.user
    ansible_ssh_private_key_file = var.priv_key_path
  }
}

resource "ansible_playbook" "local" {
  playbook   = "../ansible/playbooks/local.yml"
  name       = "localhost"
  groups     = ["local"]
  replayable = true
  check_mode = false
  verbosity  = 4
  extra_vars = {
    ansible_hostname   = "localhost"
    ansible_connection = "local"
  }
  var_files = ["../ansible/vars/env.yml", "../ansible/vars/files.yml"]

  depends_on = [
    azurerm_linux_virtual_machine.vm,
    cloudflare_dns_record.www,
    ansible_host.local,
    ansible_host.server
  ]
}

resource "ansible_playbook" "server" {
  playbook   = "../ansible/playbooks/server.yml"
  name       = azurerm_public_ip.public_ip.ip_address
  groups     = ["server"]
  replayable = true
  check_mode = false
  verbosity  = 4
  var_files  = ["../ansible/vars/env.yml", "../ansible/vars/files.yml"]

  depends_on = [
    ansible_playbook.local
  ]
}
