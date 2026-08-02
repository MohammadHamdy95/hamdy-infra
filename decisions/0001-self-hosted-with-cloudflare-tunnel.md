# ADR 0001: Self-hosted on a local server behind Cloudflare Tunnel

**Status:** accepted · **Date:** 2026-08-02

## Decision

All compute runs as containers (Docker Compose) on a local server. The
internet reaches it only through a Cloudflare Tunnel (`cloudflared`,
outbound-only) — no port forwarding, home IP never exposed. Two managed
exceptions by design: DynamoDB stores the shortener's links, and
Cloudflare handles DNS/TLS/proxy — both managed via Terraform for the
infra-as-code learning value.

## Why

- Near-zero cost (≈ $1/mo) vs ~$30–40/mo for the equivalent on AWS
- Full control of the stack; Cassandra ops experience stays real
- Terraform + AWS learning preserved through the Cloudflare and DynamoDB stacks
