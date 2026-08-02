output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.platform.id
}

output "tunnel_cname" {
  description = "What every app DNS record points at"
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.platform.id}.cfargotunnel.com"
}

output "tunnel_token" {
  description = "Set as TUNNEL_TOKEN in compose/.env on the server"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.platform.token
  sensitive   = true
}
