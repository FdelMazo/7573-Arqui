# Configure public IP
resource "azurerm_public_ip" "mgmt_public_ip" {
  name                = "mgmt_public_ip"
  location            = azurerm_resource_group.tp2_resource_group.location
  resource_group_name = azurerm_resource_group.tp2_resource_group.name
  allocation_method   = "Dynamic"
}

# Configure NIC
resource "azurerm_network_interface" "mgmt_nic" {
  name                = "mgmt_nic"
  location            = azurerm_resource_group.tp2_resource_group.location
  resource_group_name = azurerm_resource_group.tp2_resource_group.name

  ip_configuration {
    name                          = "mgmt_nic_config"
    subnet_id                     = azurerm_subnet.tp2_sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgmt_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "mgmt_nic_sg_assoc" {
  network_interface_id      = azurerm_network_interface.mgmt_nic.id
  network_security_group_id = azurerm_network_security_group.ssh_sg.id
}

#Create management VM
resource "azurerm_linux_virtual_machine" "mgmt" {
  name                  = "mgmt"
  resource_group_name   = azurerm_resource_group.tp2_resource_group.name
  location              = azurerm_resource_group.tp2_resource_group.location
  size                  = var.machine_sku
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.mgmt_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("./pubkey")
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = var.os_publisher
    offer     = var.os_offer
    sku       = var.os_sku
    version   = var.os_version
  }

  # Store the public IP
  provisioner "local-exec" {
    command = "echo ${azurerm_linux_virtual_machine.mgmt.public_ip_address} > ansible/mgmt_host"
  }

  # Store Datadog key (node)
  provisioner "local-exec" {
    command = "echo -n ${var.datadog_key} > ansible/vmss/ddog_api_key"
  }

  # Store Datadog key (python)
  provisioner "local-exec" {
    command = "echo -n ${var.datadog_key} > ansible/python/ddog_api_key"
  }
}
