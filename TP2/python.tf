# Configure NIC
resource "azurerm_network_interface" "python_nic" {
  name                = "python_nic"
  location            = azurerm_resource_group.tp2_resource_group.location
  resource_group_name = azurerm_resource_group.tp2_resource_group.name

  ip_configuration {
    name                          = "python_nic_config"
    subnet_id                     = azurerm_subnet.tp2_sn.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Create Python VM
resource "azurerm_linux_virtual_machine" "python" {
  name                  = "python"
  resource_group_name   = azurerm_resource_group.tp2_resource_group.name
  location              = azurerm_resource_group.tp2_resource_group.location
  size                  = var.machine_sku
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.python_nic.id]

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

  # Store the private IP
  provisioner "local-exec" {
    command = "echo -n ${azurerm_linux_virtual_machine.python.private_ip_address} > ansible/python/python_host"
  }

  # Use the python app IP in node code
  provisioner "local-exec" {
    command = "sed -Ei.bak \"s/(remoteBaseUri:)[^,]*,/\\1 'http:\\/\\/$(cat ansible/python/python_host):3000',/\" node/config.js"
  }
}
