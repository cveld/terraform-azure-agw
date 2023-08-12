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

    applications = {
      app1 = {
        hostname  = "app1.com"
        bepoolips = []
        priority  = "10000"
        subject   = "cn=app1.pilot.org"
        issuer    = "self"
        rewrite_rule_sets = {
          set1 = {
            rules = {
              http_to_https_redirect = {
                rewriterulename     = "http_to_https_redirect"
                rewriterulesequence = 100
                conditions = {
                  condition1 = {
                    variable = "var_request_uri"
                    pattern  = "HTTP"
                  }
                }
                urls = {
                  url1 = {
                    path         = "/api/health"
                    query_string = "verbose=true"
                  }
                }
              }
              add_custom_request_header = {
                rewriterulename     = "add_custom_request_header"
                rewriterulesequence = 200
                request_header_configurations = {
                  header1 = {
                    header_name  = "X-Custom-Header"
                    header_value = "CustomValue"
                  }
                }
              }
              add_custom_response_header = {
                rewriterulename     = "add_custom_response_header"
                rewriterulesequence = 300
                response_header_configurations = {
                  header1 = {
                    header_name  = "Strict-Transport-Security"
                    header_value = "max-age=31536000"
                  }
                }
              }
              modify_request_url = {
                rewriterulename     = "modify_request_url"
                rewriterulesequence = 400
                conditions = {
                  condition1 = {
                    variable = "var_request_uri"
                    pattern  = "/oldpath"
                  }
                }
                urls = {
                  url1 = {
                    path = "/newpath"
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
