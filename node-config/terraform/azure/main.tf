provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.azure_resource_group_name
  location = var.azure_location
}

resource "azurerm_availability_set" "main" {
  name     = var.azure_availability_set
  location = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

resource "azurerm_virtual_network" "main" {
  name                = var.azure_resource_group_name
  address_space       = [var.azure_virtual_network_prefixes]
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

resource "azurerm_subnet" "internal" {
  name                 = var.azure_subnet_name
  resource_group_name  = var.azure_resource_group_name
  virtual_network_name = var.azure_virtual_network_name
  address_prefixes     = [var.azure_subnet_prefixes]
}

resource "azurerm_network_security_group" "example" {
  name                = var.azure_security_group_name
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name

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
    name                       = "WINRM"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "MSSQL"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "map" {
  for_each            = var.nodes

  name                = "ip_${var.azure_prefix}-${each.value.name}"
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "map" {
  for_each            = var.nodes

  name                = "ni_${var.azure_prefix}-${each.value.name}"
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location
  subnet              = var.azure_subnet_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.internal.id
    public_ip_address_id          = azurerm_public_ip[each.index].id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_windows_virtual_machine" "map" {
  for_each                        = var.nodes

  name                            = "${var.prefix}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}