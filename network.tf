resource "azurerm_virtual_network" "tp2_vn" {
  name                = "tp2_network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.tp2_resource_group.location
  resource_group_name = azurerm_resource_group.tp2_resource_group.name
}

resource "azurerm_subnet" "tp2_sn" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.tp2_resource_group.name
  virtual_network_name = azurerm_virtual_network.tp2_vn.name
  address_prefixes     = ["10.0.2.0/24"]
}
