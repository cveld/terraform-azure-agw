provider "azurerm" {
  features {}
}

locals {
  naming = {
    company = "cn"
    env     = "p"
    region  = "weu"
  }
}

module "global" {
  source = "github.com/aztfmods/module-azurerm-global"
  rgs = {
    agw = {
      name     = "rg-${local.naming.company}-agw-${local.naming.env}-${local.naming.region}"
      location = "westeurope"
    }
  }
}

module "network" {
  source = "github.com/aztfmods/module-azurerm-vnet"

  naming = {
    company = local.naming.company
    env     = local.naming.env
    region  = local.naming.region
  }

  vnets = {
    demo = {
      cidr          = ["10.0.0.0/16"]
      location      = module.global.groups.agw.location
      resourcegroup = module.global.groups.agw.name
    }
  }
  depends_on = [module.global]
}

module "agw" {
  source = "../../"

  naming = {
    company = local.naming.company
    env     = local.naming.env
    region  = local.naming.region
  }

  agw = {
    location      = module.global.groups.agw.location
    resourcegroup = module.global.groups.agw.name
    waf           = { enabled = true, mode = "Detection" }
    capacity      = { min = 1, max = 2 }
    subnet_cidr   = ["10.0.0.0/27"]

    vnet = {
      name   = lookup(module.network.vnets.demo, "name", null)
      rgname = lookup(module.network.vnets.demo, "resource_group_name", null)
    }

    applications = {
      app1 = { hostname = "app1.com", bepoolips = [], priority = "10000", subject = "CN=app1.pilot.org", issuer = "Self" }
      app2 = { hostname = "app2.com", bepoolips = [], priority = "20000", subject = "CN=app2.pilot.org", issuer = "Self" }
    }
  }
  depends_on = [module.global]
}