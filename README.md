# hamdy-infra

Infrastructure for the `hamdy.app` platform: the Docker Compose stack that runs on the local server, plus Terraform for everything outside it (Cloudflare DNS/tunnel, AWS DynamoDB for the shortener).

See the workspace-level `HLD.md` for the full design.

## Layout

```
compose/
├── docker-compose.yml   # the whole platform: Caddy, cloudflared, apps, Cassandra
├── Caddyfile            # hostname → container routing
└── cloudflared/         # tunnel config
terraform/
├── cloudflare/          # DNS records, tunnel, proxy/TLS rules for all subdomains
└── aws/                 # DynamoDB links table + IAM for the shortener backend
backup/                  # nightly Cassandra snapshot scripts
decisions/               # ADRs — one short md per big choice
```

## Secrets

Nothing sensitive is ever committed. Required environment:

- `CLOUDFLARE_API_TOKEN` — for `terraform/cloudflare`
- AWS credentials (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) — for `terraform/aws`
- App runtime secrets go in `compose/.env` (gitignored; see `.env.example`)

## Bring-up

```
cd compose
docker compose up -d
```
