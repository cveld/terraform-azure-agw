# Application Gateway

This Terraform module streamlines the creation and management of azure application gateway resources, offering tailored options for routing, ssl termination, load balancing, and web application firewall configurations.

By encapsulating these complex functionalities into easy-to-use settings, this module enables rapid and reliable deployment, all managed through code.

## Goals

The main objective is to create a more logic data structure, achieved by combining and grouping related resources together in a complex object.

The structure of the module promotes reusability. It's intended to be a repeatable component, simplifying the process of building diverse workloads and platform accelerators consistently.

A primary goal is to utilize keys and values in the object that correspond to the REST API's structure. This enables us to carry out iterations, increasing its practical value as time goes on.

A last key goal is to separate logic from configuration in the module, thereby enhancing its scalability, ease of customization, and manageability.

## Features

- integrates web application firewall policy for enhanced security
- utilization of terratest for robust validation.
- supports a rewrite rule set and individual rules for customized routing
- enables self-signed or certificate authority integrated certificate generation through keyvault
- handles multiple applications

The below examples shows the usage when consuming the module:

## Usage: selfsigned certificates

```hcl
module "agw" {
  source = "github.com/aztfmods/terraform-azure-agw?ref=v1.2.0"

  workload    = var.workload
  environment = var.environment

  agw = {
    location      = module.rg.groups.demo.location
    resourcegroup = module.rg.groups.demo.name
    keyvault      = module.kv.vault.id
    subnet        = module.network.subnets.agw.id

    applications = {
      app1 = { hostname = "app1.com", bepoolips = [], priority = "10000", subject = "CN=app1.pilot.org", issuer = "self" }
      app2 = { hostname = "app2.com", bepoolips = [], priority = "20000", subject = "CN=app2.pilot.org", issuer = "self" }
    }
  }
}
```

## Usage: rewrite rule set and rules

```hcl
module "agw" {
  source = "github.com/aztfmods/terraform-azure-agw?ref=v1.2.0"

  workload    = var.workload
  environment = var.environment

  agw = {
    location      = module.rg.groups.demo.location
    resourcegroup = module.rg.groups.demo.name
    keyvault      = module.kv.vault.id
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
```

## Resources

| Name | Type |
| :-- | :-- |
| [azurerm_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_role_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_certificate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate) | resource |
| [azurerm_application_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway) | resource |
| [azurerm_web_application_firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/web_application_firewall_policy) | resource |

## Data Sources

| Name | Type |
| :-- | :-- |
| [azurerm_client_config](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | datasource |

## Inputs

| Name | Description | Type | Required |
| :-- | :-- | :-- | :-- |
| `agw` | describes application gateway related configuration | object | yes |
| `workload` | contains the workload name used, for naming convention  | string | yes |
| `environment` | contains shortname of the environment used for naming convention  | string | yes |

## Outputs

| Name | Description |
| :-- | :-- |
| `agw` | contains all application gateways |

## Testing

The github repository utilizes a Makefile to conduct tests to evaluate and validate different configurations of the module. These tests are designed to enhance its stability and reliability.

Before initiating the tests, please ensure that both go and terraform are properly installed on your system.

The [Makefile](Makefile) incorporates three distinct test variations. The first one, a local deployment test, is designed for local deployments and allows the overriding of workload and environment values. It includes additional checks and can be initiated using the command ```make test_local```.

The second variation is an extended test. This test performs additional validations and serves as the default test for the module within the github workflow.

The third variation allows for specific deployment tests. By providing a unique test name in the github workflow, it overrides the default extended test, executing the specific deployment test instead.

Each of these tests contributes to the robustness and resilience of the module. They ensure the module performs consistently and accurately under different scenarios and configurations.

## Authors

Module is maintained by [Dennis Kool](https://github.com/dkooll).

## License

MIT Licensed. See [LICENSE](https://github.com/aztfmods/terraform-azure-kv/blob/main/LICENSE) for full details.

## References

- [Documentation](https://learn.microsoft.com/en-us/azure/application-gateway/)
- [Rest Api](https://learn.microsoft.com/en-us/rest/api/application-gateway/)
- [Rest Api Specs](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/network/resource-manager/Microsoft.Network/stable/2023-04-01/applicationGateway.json)
