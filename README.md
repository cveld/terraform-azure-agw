![example workflow](https://github.com/aztfmods/module-azurerm-agw/actions/workflows/validate.yml/badge.svg)

# Application Gateway

Terraform module which creates an application gateway on Azure.

The below features are made available:

- Single application gateway deployment
- Certificate generation for each application
- WAF policy integrated
- [Selfsigned](#usage-single-agw-multiple-applications-selfsigned-certificate),[CA integrated](#usage-single-agw-multiple-applications-integrated-ca) certificates from keyvault
- [multiple](#usage-single-agw-multiple-applications-integrated-ca) applications using config
- [terratest](https://terratest.gruntwork.io) is used to validate different integrations

The below examples shows the usage when consuming the module:

## Usage: single agw multiple applications selfsigned certificate

```hcl
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
```

## Usage: single agw multiple applications integrated CA

```hcl
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
      app1 = { hostname = "app1.com", bepoolips = [], priority = "10000", subject = "CN=app1.pilot.org", issuer = "DigiCert" }
      app2 = { hostname = "app2.com", bepoolips = [], priority = "20000", subject = "CN=app2.pilot.org", issuer = "DigiCert" }
    }
  }
  depends_on = [module.global]
}
```

## Resources

| Name | Type |
| :-- | :-- |
| [azurerm_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_virtual_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_user_assigned_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [random_string](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_access_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_key_vault_certificate_issuer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate_issuer) | resource |
| [azurerm_key_vault_certificate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate) | resource |
| [azurerm_application_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway) | resource |
| [azurerm_web_application_firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/web_application_firewall_policy) | resource |

## Inputs

| Name | Description | Type | Required |
| :-- | :-- | :-- | :-- |
| `agw` | describes application gateway related configuration | object | yes |

## Outputs

| Name | Description |
| :-- | :-- |
| `agw` | contains all application gateways |

## Authors

Module is maintained by [Dennis Kool](https://github.com/dkooll) with help from [these awesome contributors](https://github.com/aztfmods/module-azurerm-agw/graphs/contributors).

## License

MIT Licensed. See [LICENSE](https://github.com/aztfmods/module-azurerm-agw/blob/main/LICENSE) for full details.
