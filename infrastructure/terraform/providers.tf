terraform {
  required_version = ">=1.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.11.0, < 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>0.4.0"
    }
    random = {}
  }
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-westeurope"
    storage_account_name = "sttfstatewesteurope"
    container_name       = "tfstate-umami"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {}
