terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # Remote state backend to be configured (see workspace HLD).
}

# Token needs: Zone:DNS:Edit, Cloudflare Tunnel:Edit. Read from
# the CLOUDFLARE_API_TOKEN environment variable — never committed.
provider "cloudflare" {}

# One DNS record per app, all proxied (orange cloud) and pointed at the
# tunnel. Adding an app = adding one entry to var.apps.
# resource "cloudflare_dns_record" "apps" {
#   for_each = var.apps
#   ...
# }
