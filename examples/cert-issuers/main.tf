provider "azurerm" {
  features {}
}

module "rg" {
  source = "github.com/aztfmods/terraform-azure-rg?ref=v0.1.0"

  environment = var.environment

  groups = {
    demo = {
      region = "westeurope"
    }
  }
}

module "network" {
  source = "github.com/aztfmods/terraform-azure-vnet?ref=v1.13.0"

  workload    = var.workload
  environment = var.environment

  vnet = {
    location      = module.rg.groups.demo.location
    resourcegroup = module.rg.groups.demo.name
    cidr          = ["10.18.0.0/16"]
    subnets = {
      agw = {
        cidr  = ["10.18.1.0/24"]
        rules = local.rules
      }
    }
  }
}

module "agw" {
  source = "../../"

  workload    = var.workload
  environment = var.environment

  agw = {
    location      = module.rg.groups.demo.location
    resourcegroup = module.rg.groups.demo.name
    subnet        = module.network.subnets.agw.id

    issuers = {
      digicert = {
        org_id     = "12345"
        provider   = "DigiCert"
        account_id = "12345"
        password   = "12345"
      }
    }

    applications = {
      app1 = { hostname = "app1.com", bepoolips = [], priority = "10000", subject = "CN=app1.pilot.org", issuer = "DigiCert" }
      app2 = { hostname = "app2.com", bepoolips = [], priority = "20000", subject = "CN=app2.pilot.org", issuer = "DigiCert" }
    }
  }
}
