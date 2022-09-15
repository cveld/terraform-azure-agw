![example workflow](https://github.com/dkooll/terraform-azurerm-vnet/actions/workflows/validate.yml/badge.svg)

# Application Gateway

Terraform module which creates an application gateway on Azure.

The below features are made available:

- Single application gateway deployment
- Ability to specify multiple applications using config
- Certificate generation for each application
- Selfsigned certificates and CA integrated from keyvault
- WAF policy integrated
- Terratest is used to validate different integrations in [examples](examples)

The below examples shows the usage when consuming the module:

## Usage: single agw multiple applications selfsigned certificate

```hcl
module "agw" {
  source = "../../"
  agw = {
    location = "westeurope"
    cidr     = { vnet = ["10.0.0.0/16"], snet = ["10.0.0.0/27"] }
    waf      = { enabled = true, mode = "Detection" }
    capacity = { min = 1, max = 2 }

    applications = {
      app1 = { hostname = "app1.com", bepoolips = [], priority = "10000", subject = "CN=app1.pilot.org", issuer = "Self" }
      app2 = { hostname = "app2.com", bepoolips = [], priority = "20000", subject = "CN=app2.pilot.org", issuer = "Self" }
    }
  }
}
```

## Usage: single agw multiple applications integrated CA

```hcl
module "agw" {
  source = "../../"
  agw = {
    location    = "westeurope"
    cidr        = { vnet = ["10.0.0.0/16"], snet = ["10.0.0.0/27"] }
    cert_issuer = { name = "DigiCert", org_id = "12345", account_id = "12345" }
    waf         = { enabled = true, mode = "Detection" }
    capacity    = { min = 1, max = 2 }

    applications = {
      app1 = { hostname = "app1.com", bepoolips = [], priority = "10000", subject = "CN=app1.pilot.org", issuer = "DigiCert" }
      app2 = { hostname = "app2.com", bepoolips = [], priority = "20000", subject = "CN=app2.pilot.org", issuer = "DigiCert" }
    }
  }
}
```

## Resources

| Name | Type |
| :-- | :-- |
| [azurerm_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_virtual_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_user_assigned_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [random_string](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_key_vault_access_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_key_vault_certificate_issuer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_key_vault_certificate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_application_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_web_application_firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |

## Inputs

| Name | Description | Type | Required |
| :-- | :-- | :-- | :-- |
| `vnets` | describes vnet related configuration | object | yes |
| `resourcegroup` | name of the resource group | string | yes |

## Outputs

| Name | Description |
| :-- | :-- |
| `subnets` | contains all subnets |
| `vnets` | contains all vnets |

## Authors

Module is maintained by [Dennis Kool](https://github.com/dkooll) with help from [these awesome contributors](https://github.com/dkooll/terraform-azurerm-vnet/graphs/contributors).

## License

MIT Licensed. See [LICENSE](https://github.com/dkooll/terraform-azurerm-vnet/tree/master/LICENSE) for full details.