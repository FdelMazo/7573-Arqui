resource "azurerm_linux_virtual_machine_scale_set" "tp2_vmss" {
  name                = "tp2vmss"
  resource_group_name = azurerm_resource_group.tp2_resource_group.name
  location            = azurerm_resource_group.tp2_resource_group.location
  sku                 = var.machine_sku
  instances           = 1
  admin_username      = "azureuser"
  depends_on          = [azurerm_lb_rule.lb_rule]
  upgrade_mode        = "Automatic"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("./pubkey")
  }

  source_image_reference {
    publisher = var.os_publisher
    offer     = var.os_offer
    sku       = var.os_sku
    version   = var.os_version
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "node_nic"
    primary = true

    ip_configuration {
      name                                   = "node_nic_config"
      primary                                = true
      subnet_id                              = azurerm_subnet.tp2_sn.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lb_backend_address_pool.id]
    }
  }
}

resource "azurerm_public_ip" "lb_public_ip" {
  name                = "lb_public_ip"
  location            = azurerm_resource_group.tp2_resource_group.location
  resource_group_name = azurerm_resource_group.tp2_resource_group.name
  allocation_method   = "Dynamic"
  domain_name_label   = var.group_prefix
}

resource "azurerm_lb" "tp2_lb" {
  name                = "tp2_lb"
  location            = azurerm_resource_group.tp2_resource_group.location
  resource_group_name = azurerm_resource_group.tp2_resource_group.name

  frontend_ip_configuration {
    name                       = "tp2_lb_public_ip"
    public_ip_address_id       = azurerm_public_ip.lb_public_ip.id
    private_ip_address_version = "IPv4"
  }

  provisioner "local-exec" {
    command = "echo ${azurerm_public_ip.lb_public_ip.fqdn} > node/lb_dns"
  }
}

resource "azurerm_lb_probe" "lb_probe" {
  name            = "lb_probe"
  loadbalancer_id = azurerm_lb.tp2_lb.id
  port            = 3000
}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.tp2_lb.id
  name                           = "HTTPFwd"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 3000
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_address_pool.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
  frontend_ip_configuration_name = azurerm_lb.tp2_lb.frontend_ip_configuration[0].name
}

resource "azurerm_lb_backend_address_pool" "lb_backend_address_pool" {
  loadbalancer_id = azurerm_lb.tp2_lb.id
  name            = "lb_backend_address_pool"
}
