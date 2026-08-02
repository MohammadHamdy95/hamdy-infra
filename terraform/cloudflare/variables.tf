variable "zone" {
  description = "Apex zone"
  type        = string
  default     = "hamdy.app"
}

# Subdomains routed through the tunnel. Adding a new app = one entry here.
variable "apps" {
  description = "Map of subdomain => description"
  type        = map(string)
  default = {
    "@"         = "hamdy-app — flagship portfolio"
    "s"         = "URL shortener (UI + short links)"
    "paste"     = "paste app UI"
    "api.paste" = "paste API"
  }
}
