locals {
  app_gateway = [
    for app_key, app in try(var.agw.applications, {}) : {
      app_key                 = app_key
      http_listener_name      = "listener-${app_key}"
      http_listener_host_name = app.hostname
      bepoolname              = "bep-${app_key}"
      bepoolips               = app.bepoolips
      routerulename           = "rule-${app_key}"
      priority                = app.priority
      ssl_certificate_name    = "cert-${app_key}"
      key_vault_secret_id     = azurerm_key_vault_certificate.cert[app_key].secret_id

      rewrite_rule_sets = [
        for set_key, set in try(app.rewrite_rule_sets, {}) : {
          set_key            = set_key
          rewriterulesetname = set_key
          rules = [
            for rule_key, rule in set.rules : {
              rule_key            = rule_key
              rewriterulename     = rule.rewriterulename
              rewriterulesequence = rule.rewriterulesequence
              conditions = [
                for condition_key, condition in try(rule.conditions, {}) : {
                  variable    = condition.variable
                  pattern     = condition.pattern
                  ignore_case = try(condition.ignore_case, false)
                  negate      = try(condition.negate, false)
                }
              ]
              request_header_configurations = [
                for header_key, header in try(rule.request_header_configurations, {}) : {
                  header_key   = header_key
                  header_name  = header.header_name
                  header_value = header.header_value
                }
              ]
              response_header_configurations = [
                for header_key, header in try(rule.response_header_configurations, {}) : {
                  header_key   = header_key
                  header_name  = header.header_name
                  header_value = header.header_value
                }
              ]
              urls = [
                for url_key, url in try(rule.urls, {}) : {
                  url_key      = url_key
                  path         = try(url.path, null)
                  query_string = try(url.query_string, null)
                  components   = try(url.components, null)
                  reroute      = try(url.reroute, null)
                }
              ]
            }
          ]
        }
      ]
    }
  ]

  routing_rules_map = [
    for app_key, app in try(var.agw.applications, {}) : {
      app_key               = app_key,
      routerulename         = "rule-${app_key}",
      priority              = app.priority,
      rewrite_rule_set_name = try(length(app.rewrite_rule_sets) > 0 ? keys(app.rewrite_rule_sets)[0] : null, null)
    }
  ]

  rewrite_rule_sets_map = {
    for app_key, app in local.app_gateway : app_key => app.rewrite_rule_sets
  }

  issuers = flatten([
    for issuer_key, issuer in try(var.agw.issuers, {}) : {

      issuer_key    = issuer_key
      name          = "issuer-${var.workload}-${issuer_key}-${var.environment}"
      key_vault_id  = var.agw.key_vault_id
      provider_name = issuer.provider
      account_id    = try(issuer.account_id, null)
      password      = try(issuer.password, null)
      org_id        = try(issuer.org_id, null)
    }
  ])
}
