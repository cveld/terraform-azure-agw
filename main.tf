data "azurerm_client_config" "current" {}

# public ip
resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.workload}-${var.environment}"
  resource_group_name = var.agw.resourcegroup
  location            = var.agw.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# user assigned identity
resource "azurerm_user_assigned_identity" "mi" {
  name                = "mi-${var.workload}-${var.environment}"
  resource_group_name = var.agw.resourcegroup
  location            = var.agw.location
}

# role assignments
resource "azurerm_role_assignment" "mi_role_assignment" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_user_assigned_identity.mi.principal_id
}

resource "azurerm_role_assignment" "spn_role_assignment" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# random id
resource "random_string" "random" {
  length    = 3
  min_lower = 3
  special   = false
  numeric   = false
  upper     = false
}

# keyvault
resource "azurerm_key_vault" "kv" {
  name                      = "kv-${var.workload}-${var.environment}-${random_string.random.result}"
  location                  = var.agw.location
  resource_group_name       = var.agw.resourcegroup
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

# certificate issuers
resource "azurerm_key_vault_certificate_issuer" "issuer" {
  for_each = {
    for issuer in local.issuers : issuer.issuer_key => issuer
  }

  name          = each.value.name
  org_id        = each.value.org_id
  key_vault_id  = each.value.key_vault_id
  provider_name = each.value.provider_name
  account_id    = each.value.account_id
  password      = each.value.password //pat certificate authority

  depends_on = [
    azurerm_role_assignment.mi_role_assignment,
    azurerm_role_assignment.spn_role_assignment
  ]
}

# keyvault certificate
resource "azurerm_key_vault_certificate" "cert" {
  for_each = try(var.agw.applications, {})

  name         = "cert-${var.workload}-${each.key}-${var.environment}"
  key_vault_id = azurerm_key_vault.kv.id

  certificate_policy {
    issuer_parameters {
      name = each.value.issuer
    }

    key_properties {
      exportable = each.value.issuer == "self" ? true : false
      key_type   = try(each.value.key_type, "RSA")
      key_size   = try(each.value.key_size, 2048)
      reuse_key  = try(each.value.reuse_key, false)
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    x509_certificate_properties {
      subject            = each.value.subject
      validity_in_months = try(each.value.validity_in_months, 12)

      key_usage = try(each.value.key_usage, [
        "cRLSign", "dataEncipherment",
        "digitalSignature", "keyAgreement",
        "keyCertSign", "keyEncipherment",
      ])
    }
  }
  depends_on = [
    azurerm_role_assignment.mi_role_assignment,
    azurerm_role_assignment.spn_role_assignment
  ]
}

# application gateway
resource "azurerm_application_gateway" "agw" {
  name                = "agw-${var.workload}-${var.environment}"
  resource_group_name = var.agw.resourcegroup
  location            = var.agw.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.waf_policy.id

  enable_http2 = try(var.agw.enable.http2, false)

  sku {
    name = try(var.agw.sku.name, "WAF_v2")
    tier = try(var.agw.sku.tier, "WAF_v2")
  }

  autoscale_configuration {
    min_capacity = try(var.agw.autoscale.min, 1)
    max_capacity = try(var.agw.autoscale.max, 2)
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.mi.id]
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = var.agw.subnet
  }

  frontend_ip_configuration {
    name                 = "feip"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  frontend_port {
    name = "fep"
    port = 443
  }

  backend_http_settings {
    cookie_based_affinity = "Disabled"
    name                  = "backend-http-settings"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
  }

  dynamic "ssl_certificate" {
    for_each = {
      for gw in local.app_gateway : gw.app_key => gw
    }

    content {
      name                = ssl_certificate.value.ssl_certificate_name
      key_vault_secret_id = ssl_certificate.value.key_vault_secret_id
    }
  }

  dynamic "http_listener" {
    for_each = {
      for gw in local.app_gateway : gw.app_key => gw
    }

    content {
      name                           = http_listener.value.http_listener_name
      frontend_ip_configuration_name = "feip"
      frontend_port_name             = "fep"
      host_name                      = http_listener.value.http_listener_host_name
      protocol                       = "Https"
      ssl_certificate_name           = http_listener.value.ssl_certificate_name
    }
  }

  dynamic "backend_address_pool" {
    for_each = {
      for gw in local.app_gateway : gw.app_key => gw
    }

    content {
      name         = backend_address_pool.value.bepoolname
      ip_addresses = backend_address_pool.value.bepoolips
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.routing_rules_map

    content {
      name                       = request_routing_rule.value.routerulename
      rule_type                  = "Basic"
      http_listener_name         = "listener-${request_routing_rule.value.app_key}"
      backend_address_pool_name  = "bep-${request_routing_rule.value.app_key}"
      backend_http_settings_name = "backend-http-settings"
      priority                   = request_routing_rule.value.priority
      rewrite_rule_set_name      = request_routing_rule.value.rewrite_rule_set_name != null ? request_routing_rule.value.rewrite_rule_set_name : null
    }
  }

  dynamic "rewrite_rule_set" {
    for_each = flatten([
      for app_key, rule_sets in local.rewrite_rule_sets_map : [
        for rule_set in rule_sets : merge(rule_set, { app_key = app_key })
      ]
    ])

    content {
      name = rewrite_rule_set.value.set_key

      dynamic "rewrite_rule" {
        for_each = rewrite_rule_set.value.rules

        content {
          name          = rewrite_rule.value.rewriterulename
          rule_sequence = rewrite_rule.value.rewriterulesequence

          dynamic "condition" {
            for_each = rewrite_rule.value.conditions

            content {
              variable    = condition.value.variable
              pattern     = condition.value.pattern
              ignore_case = condition.value.ignore_case
              negate      = condition.value.negate
            }
          }

          dynamic "request_header_configuration" {
            for_each = rewrite_rule.value.request_header_configurations

            content {
              header_name  = request_header_configuration.value.header_name
              header_value = request_header_configuration.value.header_value
            }
          }

          dynamic "response_header_configuration" {
            for_each = rewrite_rule.value.response_header_configurations

            content {
              header_name  = response_header_configuration.value.header_name
              header_value = response_header_configuration.value.header_value
            }
          }

          dynamic "url" {
            for_each = rewrite_rule.value.urls

            content {
              path         = url.value.path
              query_string = url.value.query_string
              components   = url.value.components
              reroute      = url.value.reroute
            }
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      waf_configuration,
    ]
  }
}

# waf policy
resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "waf-${var.workload}-${var.environment}"
  resource_group_name = var.agw.resourcegroup
  location            = var.agw.location

  policy_settings {
    enabled = try(var.agw.waf.enable, true)
    mode    = try(var.agw.waf.mode, "Prevention")
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}
