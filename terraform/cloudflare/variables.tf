variable "account_id" {
  description = "Cloudflare account ID (dashboard → overview, right sidebar)"
  type        = string
}

variable "zone_id" {
  description = "Zone ID for the apex zone (dashboard → overview, right sidebar)"
  type        = string
}

variable "zone" {
  description = "Apex zone"
  type        = string
  default     = "hamdy.app"
}

# Subdomains routed through the tunnel. Adding a new app = one entry here.
variable "apps" {
  description = "Map of subdomain (\"@\" for apex) => description"
  type        = map(string)
  default = {
    "@"     = "hamdy-app - flagship portfolio"
    "tiny"  = "URL shortener (UI + short links)"
    "paste" = "paste app (UI + API, path-routed)"
  }
}
