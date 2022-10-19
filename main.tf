data "azurerm_client_config" "current" {}

#----------------------------------------------------------------------------------------
# resourcegroup
#----------------------------------------------------------------------------------------

data "azurerm_resource_group" "rg" {
  name = var.agw.resourcegroup
}

#----------------------------------------------------------------------------------------
# Vnet / subnets
#----------------------------------------------------------------------------------------

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.naming.company}-${var.naming.env}-${var.naming.region}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  address_space       = var.agw.cidr.vnet
}

resource "azurerm_subnet" "subnet" {
  name                 = "sn-${var.naming.company}-${var.naming.env}-${var.naming.region}"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.agw.cidr.snet
}

# ----------------------------------------------------------------------------------------
# public ip
# ----------------------------------------------------------------------------------------

resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.naming.company}-${var.naming.env}-${var.naming.region}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ----------------------------------------------------------------------------------------
# user assigned identity
# ----------------------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "mi" {
  name                = "mi-${var.naming.company}-${var.naming.env}-${var.naming.region}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
}

#----------------------------------------------------------------------------------------
# generate random id
#----------------------------------------------------------------------------------------

resource "random_string" "random" {
  length    = 3
  min_lower = 3
  special   = false
  numeric   = false
  upper     = false
}

# ----------------------------------------------------------------------------------------
# keyvault
# ----------------------------------------------------------------------------------------

resource "azurerm_key_vault" "kv" {
  name                = "kv${var.naming.company}${var.naming.env}${var.naming.region}${random_string.random.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

# ----------------------------------------------------------------------------------------
# keyvault access policy managed identity
# ----------------------------------------------------------------------------------------

resource "azurerm_key_vault_access_policy" "polmi" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.mi.principal_id

  certificate_permissions = [
    "Create", "Get", "GetIssuers", "List",
    "ListIssuers", "Import", "Update",
    "Recover", "Purge", "Delete",
  ]
  key_permissions = [
    "Get", "List", "Purge"
  ]
  secret_permissions = [
    "Delete", "Get", "List",
    "Purge", "Recover", "Set"
  ]
}

# ----------------------------------------------------------------------------------------
# keyvault access policy spn
# ----------------------------------------------------------------------------------------

resource "azurerm_key_vault_access_policy" "polspn" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  certificate_permissions = [
    "Create", "Get", "GetIssuers", "List",
    "ListIssuers", "Import", "Update",
    "Recover", "Purge", "Delete", "SetIssuers",
    "DeleteIssuers"
  ]

  key_permissions = [
    "Get", "List", "Purge"
  ]
  secret_permissions = [
    "Delete", "Get", "List",
    "Purge", "Recover", "Set"
  ]
}

# ----------------------------------------------------------------------------------------
# generate password CA token
# ----------------------------------------------------------------------------------------

resource "random_string" "randomca" {
  length    = 12
  min_lower = 6
  special   = true
  numeric   = true
  upper     = true
}

resource "azurerm_key_vault_secret" "pat" {
  name         = "ca-pat"
  value        = random_string.randomca.result
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.polspn,
    azurerm_key_vault_access_policy.polmi
  ]
}

# ----------------------------------------------------------------------------------------
# keyvault certificate issuer
# ----------------------------------------------------------------------------------------

resource "azurerm_key_vault_certificate_issuer" "issuer" {
  for_each = try(var.agw.cert_issuer, {})

  name          = each.value.name
  org_id        = each.value.org_id
  key_vault_id  = azurerm_key_vault.kv.id
  provider_name = each.value.name
  account_id    = each.value.account_id
  password      = azurerm_key_vault_secret.pat.value

  depends_on = [
    azurerm_key_vault_access_policy.polspn,
    azurerm_key_vault_access_policy.polmi
  ]
}

# ----------------------------------------------------------------------------------------
# keyvault certificate
# ----------------------------------------------------------------------------------------

resource "azurerm_key_vault_certificate" "cert" {
  for_each = try(var.agw.applications, {})

  name         = "cert-${var.naming.company}-${each.key}-${var.naming.env}-${var.naming.region}"
  key_vault_id = azurerm_key_vault.kv.id

  certificate_policy {
    issuer_parameters {
      name = each.value.issuer
    }
    key_properties {
      exportable = each.value.issuer == "Self" ? true : false
      key_type   = "RSA"
      key_size   = "2048"
      reuse_key  = false
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    x509_certificate_properties {
      subject            = each.value.subject
      validity_in_months = "12"
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]
    }
  }
  depends_on = [
    azurerm_key_vault_access_policy.polspn,
    azurerm_key_vault_access_policy.polmi
  ]
}

# ----------------------------------------------------------------------------------------
# application gateway
# ----------------------------------------------------------------------------------------

resource "azurerm_application_gateway" "application_gateway" {
  name                = "agw-${var.naming.company}-${var.naming.env}-${var.naming.region}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.waf_policy.id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.mi.id]
  }

  autoscale_configuration {
    max_capacity = var.agw.capacity.max
    min_capacity = var.agw.capacity.min
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = azurerm_subnet.subnet.id
  }

  frontend_ip_configuration {
    name                 = "feip-prd-${var.naming.region}-001"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  frontend_port {
    name = "fep-prd-${var.naming.region}-001"
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
      frontend_ip_configuration_name = "feip-prd-${var.naming.region}-001"
      frontend_port_name             = "fep-prd-${var.naming.region}-001"
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
    for_each = {
      for gw in local.app_gateway : gw.app_key => gw
    }

    content {
      name                       = request_routing_rule.value.routerulename
      rule_type                  = "Basic"
      http_listener_name         = request_routing_rule.value.http_listener_name
      backend_address_pool_name  = request_routing_rule.value.bepoolname
      backend_http_settings_name = "backend-http-settings"
      priority                   = request_routing_rule.value.priority
    }
  }
  lifecycle {
    ignore_changes = [
      waf_configuration,
    ]
  }
}

# ----------------------------------------------------------------------------------------
# application gateway waf policy global
# ----------------------------------------------------------------------------------------

resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "waf-${var.naming.company}-${var.naming.env}-${var.naming.region}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  policy_settings {
    enabled = var.agw.waf.enabled
    mode    = var.agw.waf.mode
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}