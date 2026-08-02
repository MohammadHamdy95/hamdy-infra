terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state backend to be configured (see workspace HLD).
}

# Token needs: Zone:DNS:Edit, Account:Cloudflare Tunnel:Edit. Read from
# the CLOUDFLARE_API_TOKEN environment variable — never committed.
provider "cloudflare" {}

resource "random_bytes" "tunnel_secret" {
  length = 64
}

# The single tunnel every subdomain routes through.
resource "cloudflare_zero_trust_tunnel_cloudflared" "platform" {
  account_id    = var.account_id
  name          = "hamdy-platform"
  tunnel_secret = random_bytes.tunnel_secret.base64
  config_src    = "cloudflare"
}

# Tunnel ingress: hand every hostname to Caddy, which routes by Host header.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "platform" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.platform.id

  config = {
    ingress = concat(
      [
        for sub, _ in var.apps : {
          hostname = sub == "@" ? var.zone : "${sub}.${var.zone}"
          service  = "http://caddy:80"
        }
      ],
      [{ service = "http_status:404" }] # catch-all, required last rule
    )
  }
}

# The token cloudflared runs with on the server (TUNNEL_TOKEN in compose/.env).
data "cloudflare_zero_trust_tunnel_cloudflared_token" "platform" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.platform.id
}

# One proxied CNAME per app pointing at the tunnel. Adding an app = one
# entry in var.apps.
resource "cloudflare_dns_record" "apps" {
  for_each = var.apps

  zone_id = var.zone_id
  name    = each.key == "@" ? var.zone : "${each.key}.${var.zone}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.platform.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # auto (required when proxied)
  comment = each.value
}
