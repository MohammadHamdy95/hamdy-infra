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
    "spec"  = "OpenAPI spec sharing (UI + API, path-routed)"
    "panel" = "Pterodactyl panel (game server management UI)"
    "node"  = "Pterodactyl Wings API + console websocket"
    # NOTE: play.hamdy.app is gone as of 2026-09-05 -- the record is deleted and
    # nothing serves the name. It ran NodeCast TV, which has been replaced by
    # ninja-player on the bes platform at play.bes.ninja (its own repo, built
    # and deployed by bes-infra). The service moved because it became a
    # customer-facing business service rather than a personal utility.
    #
    # Kept as a note rather than deleted outright, because the reasoning still
    # applies to anything similar: a video host must NOT go in this map. Every
    # entry here is a proxied tunnel record, and Cloudflare's free plan is not
    # a video CDN -- adding one would pull streaming through the proxy. Such a
    # host wants a grey-cloud CNAME to bes.ninja served directly by
    # bes-master's Caddy, which is what desktop.hamdy.app still does.
  }
}

# The game server's public IP. Minecraft speaks raw TCP, which Cloudflare's
# proxy cannot carry on a non-Enterprise plan, so `mc` is the platform's one
# unproxied record pointing straight here — see decisions/0002.
#
# Residential IPs move. The cloudflare-ddns container in the pterodactyl
# stack rewrites this record when that happens, so a stale default here is
# self-correcting; Terraform will just show a drift on the next plan.
variable "home_ip" {
  description = "Public IPv4 of the home server (cosmosworld.hamdy.app A record)"
  type        = string
  default     = "107.219.133.158"
}

variable "game_subdomain" {
  description = "Subdomain players connect to"
  type        = string
  default     = "cosmosworld"
}
