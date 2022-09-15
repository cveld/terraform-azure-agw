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