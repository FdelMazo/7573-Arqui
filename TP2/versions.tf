terraform {
  required_version = "~>1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.28"
    }

    template = {
      source  = "hashicorp/template"
      version = "~>2.2"
    }

    local = {
      source  = "hashicorp/local"
      version = "~>2.2"
    }
  }
}
