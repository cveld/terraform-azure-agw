locals {
  app_gateway = flatten([
    for app_key, app in var.agw.applications : {

      app_key                 = app_key
      http_listener_name      = "listener-${app_key}-${var.naming.env}"
      http_listener_host_name = app.hostname
      bepoolname              = "bep-${app_key}-${var.naming.env}"
      bepoolips               = app.bepoolips
      routerulename           = "rule-${app_key}-${var.naming.env}"
      priority                = app.priority
      ssl_certificate_name    = "cert-${app_key}-${var.naming.env}"
      key_vault_secret_id     = azurerm_key_vault_certificate.cert[app_key].secret_id
    }
  ])
}