variable "datadog_key" {
}

variable "group_prefix" {
}

variable "region" {
  default = "eastus"
}

variable "os_publisher" {
  default = "Debian"
}

variable "os_offer" {
  default = "debian-10"
}

variable "os_sku" {
  default = "10"
}

variable "os_version" {
  default = "latest"
}

variable "machine_sku" {
  default = "Standard_B1ls"
}
